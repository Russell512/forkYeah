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
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入')));
      Navigator.pop(context);
      return;
    }

    final cartRes = await supa
        .from('carts')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (cartRes == null) {
      setState(() {
        _items = [];
        _isLoading = false;
      });
      return;
    }

    final cartId = cartRes['id'] as String;
    final data = await supa
        .from('cart_items')
        .select('quantity, food_items(id, name, price)')
        .eq('cart_id', cartId);

    setState(() {
      _items = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
    });
  }

  Future<void> _updateQuantity(String foodItemId, int newQty) async {
    debugPrint('🔧 _updateQuantity called for $foodItemId → $newQty');
    try {
      final user = supa.auth.currentUser;
      if (user == null) return;

      // 取得 cartId（同前）
      final rawCart = await supa
          .from('carts')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
      final cart = rawCart as Map<String, dynamic>?;
      if (cart == null) return;
      final cartId = cart['id'] as String;

      if (newQty <= 0) {
        // 刪掉 DB 裡的那筆
        await supa
            .from('cart_items')
            .delete()
            .eq('cart_id', cartId)
            .eq('food_item_id', foodItemId);

        // 立即從本地清單移除
        setState(() {
          _items.removeWhere((item) =>
          (item['food_items'] as Map<String, dynamic>)['id'] == foodItemId
          );
        });
        debugPrint('🗑 item removed locally');
      } else {
        // 更新數量
        await supa
            .from('cart_items')
            .update({'quantity': newQty})
            .eq('cart_id', cartId)
            .eq('food_item_id', foodItemId);
        // 重新取一次或同步更新本地列表
        await _loadCartItems();
      }

      debugPrint('🔄 update finished');
    } catch (e, st) {
      debugPrint('❌ _updateQuantity exception: $e\n$st');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    }
  }



  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(
      0,
          (prev, curr) {
        final qty = curr['quantity'] as int;
        final price = (curr['food_items']['price'] as num)
            .toDouble();
        return prev + price * qty;
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
              separatorBuilder: (_, __) =>
              const Divider(),
              itemBuilder: (context, index) {
                final item = _items[index];
                final food = item['food_items']
                as Map<String, dynamic>;
                final qty = item['quantity'] as int;
                final price =
                (food['price'] as num).toDouble();
                final sub = price * qty;
                return ListTile(
                  title: Text(food['name']
                  as String),
                  subtitle: Text(
                      '單價 \$${price.toStringAsFixed(2)}  x $qty  =  \$${sub.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          debugPrint('➖ tapped remove for ${food['id']} (qty=$qty)');
                          _updateQuantity(food['id'] as String, qty - 1);
                        },
                      ),
                      Text(qty.toString()),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          debugPrint('➕ tapped add for ${food['id']} (qty=$qty)');
                          _updateQuantity(food['id'] as String, qty + 1);
                        },
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
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                const Text('總金額',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold)),
                Text('\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
