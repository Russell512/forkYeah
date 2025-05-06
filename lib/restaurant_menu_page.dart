import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'food_item_editor.dart';

class RestaurantMenuPage extends StatefulWidget {
  const RestaurantMenuPage({super.key});

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage> {
  final supa = Supabase.instance.client;
  late final String uid;
  List<Map<String, dynamic>> items = [];
  String keyword = '';

  @override
  void initState() {
    super.initState();
    uid = supa.auth.currentUser!.id;
    _ensureProfile();     // <── NEW
    _loadItems();
  }

  /* ---------- 讓外鍵永遠 pass ---------- */
  Future<void> _ensureProfile() async {
    final rows = await supa.from('users').select('id').eq('id', uid);
    if (rows.isEmpty) {
      await supa.from('users').insert({
        'id'   : uid,
        'email': supa.auth.currentUser!.email,
        'role' : 'restaurant',
      });
    }
  }

  /* ---------------- CRUD ---------------- */
  Future<void> _loadItems({String search = ''}) async {
    var q = supa
        .from('food_items')
        .select()
        .eq('restaurant_id', uid);

    if (search.isNotEmpty) q = q.like('name', '%$search%');

    final data = await q.order('created_at', ascending: false);

    if (mounted) {
      setState(() => items = List<Map<String, dynamic>>.from(data));
    }
  }

  Future<void> _deleteItem(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確定刪除？'),
        content: const Text('此操作無法復原'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    await supa.from('food_items').delete().eq('id', id);
    _loadItems(search: keyword);
  }

  Future<void> _openEditor([Map<String, dynamic>? item]) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FoodItemEditor(item: item)),
    );
    if (updated == true) _loadItems(search: keyword);
  }

  /* ---------------- UI ------------------ */
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('商家商品管理')),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () => _openEditor(),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜尋商品名稱',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  keyword = v.trim();
                  _loadItems(search: keyword);
                },
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('沒有資料'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (it['image_url'] ?? '').isNotEmpty
                                ? NetworkImage(it['image_url'])
                                : null,
                            child: (it['image_url'] ?? '').isEmpty
                                ? const Icon(Icons.image_not_supported)
                                : null,
                          ),
                          title: Text(it['name']),
                          subtitle: Text('\$${it['price']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteItem(it['id']),
                          ),
                          onTap: () => _openEditor(it),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
}
