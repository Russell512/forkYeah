import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});
  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final supa = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadMyOrders();
  }

  Future<void> _loadMyOrders() async {
    setState(() => _loading = true);
    final user = supa.auth.currentUser;
    if (user == null) return;
    final data = await supa
        .from('orders')
        .select('id,total_amount,status,created_at')
        .eq('delivery_id', user.id)
        .order('created_at', ascending: false);
    _orders = List<Map<String, dynamic>>.from(data);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的訂單')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text('尚未指派任何訂單'))
          : ListView.separated(
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) {
          final o = _orders[i];
          final total = (o['total_amount'] as num).toDouble();
          return ListTile(
            title: Text('訂單 ${o['id']}'),
            subtitle: Text(
                '狀態：${o['status']}  總金額 \$${total.toStringAsFixed(2)}'),
            trailing: Text(
              (o['created_at'] as String).substring(0, 19),
            ),
          );
        },
      ),
    );
  }
}
