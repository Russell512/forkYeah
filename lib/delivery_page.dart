import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final supa = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    final data = await supa
        .from('orders')
        .select('id,user_id,total_amount,created_at')
        .is_('delivery_id', null)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    _orders = List<Map<String, dynamic>>.from(data);
    setState(() => _loading = false);
  }

  Future<void> _assign() async {
    final user = supa.auth.currentUser!;
    try {
      for (final id in _selected) {
        await supa
            .from('orders')
            .update({'delivery_id': user.id, 'status': 'assigned'})
            .eq('id', id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已指派 ${_selected.length} 筆訂單')));
      _selected.clear();
      await _loadPending();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('指派失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('待領取訂單')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text('目前沒有待領取訂單'))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (c, i) {
                final o = _orders[i];
                final id = o['id'] as String;
                final total = (o['total_amount'] as num).toDouble();
                return CheckboxListTile(
                  title: Text('訂單 $id'),
                  subtitle:
                  Text('總金額 \$${total.toStringAsFixed(2)}'),
                  value: _selected.contains(id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true)
                        _selected.add(id);
                      else
                        _selected.remove(id);
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed:
              _selected.isEmpty ? null : () => _assign(),
              child: const Text('指派訂單'),
            ),
          )
        ],
      ),
    );
  }
}
