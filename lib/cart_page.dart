import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    setState(() => _isLoading = true);
    final user = supa.auth.currentUser;
    if (user == null) return;

    // 取得 cartId
    final rawCart = await supa
        .from('carts')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();
    final cart = rawCart as Map<String, dynamic>?;
    if (cart == null) {
      setState(() {
        _items = [];
        _isLoading = false;
      });
      return;
    }
    final cartId = cart['id'] as String;

    // 撈 quantity > 0 的項目
    final rawData = await supa
        .from('cart_items')
        .select('quantity, food_items(id, name, price)')
        .eq('cart_id', cartId)
        .gt('quantity', 0);
    final items = List<Map<String, dynamic>>.from(rawData);

    debugPrint('🌐 [load] 撈到 ${items.length} 筆：' +
        items.map((e) => (e['food_items'] as Map)['id']).toList().toString());

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _updateQuantity(String foodItemId, int newQty) async {
    debugPrint('🔧 _updateQuantity for $foodItemId → $newQty');
    try {
      final user = supa.auth.currentUser;
      if (user == null) return;
      final rawCart = await supa
          .from('carts')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
      final cart = rawCart as Map<String, dynamic>?;
      if (cart == null) return;
      final cartId = cart['id'] as String;

      // 只更新數量
      await supa
          .from('cart_items')
          .update({'quantity': newQty})
          .eq('cart_id', cartId)
          .eq('food_item_id', foodItemId);
      debugPrint('✏️ update OK to qty=$newQty');

      await _loadCartItems();
    } catch (e, st) {
      debugPrint('❌ _updateQuantity error: $e\n$st');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }

  Future<void> _deleteItem(String foodItemId) async {
    debugPrint('🗑 [delete] 開始刪除 $foodItemId');
    final user = supa.auth.currentUser;
    if (user == null) return;

    // 取得 cartId
    final rawCart = await supa
        .from('carts')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();
    final cart = rawCart as Map<String, dynamic>?;
    if (cart == null) return;
    final cartId = cart['id'] as String;

    // 執行刪除並返回刪除的 row
    await supa
        .from('cart_items')
        .delete()
        .eq('cart_id', cartId)
        .eq('food_item_id', foodItemId);
    debugPrint('🗑 delete OK');

    // 重新撈一次
    await _loadCartItems();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已從購物車移除')));
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(
      0,
          (sum, item) {
        final qty = item['quantity'] as int;
        final price = (item['food_items']['price'] as num).toDouble();
        return sum + price * qty;
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('我的購物車')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('購物車內沒有商品'))
          : Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, index) {
                final item = _items[index];
                final food =
                item['food_items'] as Map<String, dynamic>;
                final qty = item['quantity'] as int;
                final price =
                (food['price'] as num).toDouble();
                final sub = price * qty;

                return ListTile(
                  title: Text(food['name'] as String),
                  subtitle: Text(
                      '\$${price.toStringAsFixed(2)} × $qty ＝ \$${sub.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 減少數量
                      IconButton(
                        icon:
                        const Icon(Icons.remove_circle_outline),
                        onPressed: () =>
                            _updateQuantity(food['id'] as String,
                                qty - 1),
                      ),
                      Text(qty.toString()),
                      // 增加數量
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () =>
                            _updateQuantity(food['id'] as String,
                                qty + 1),
                      ),
                      // 刪除該筆
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () =>
                            _deleteItem(food['id'] as String),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('總金額：\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: _items.isEmpty ? null : () {},
                  child: const Text('結帳'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
