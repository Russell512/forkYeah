import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantDetailPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const RestaurantDetailPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<RestaurantDetailPage> createState() =>
      _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  final supa = Supabase.instance.client;
  List<Map<String, dynamic>> _foodItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFoodItems();
  }

  Future<void> _loadFoodItems() async {
    setState(() => _isLoading = true);
    try {
      final data = await supa
          .from('food_items')
          .select()
          .eq('restaurant_id', widget.restaurantId)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _foodItems = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加載商品失敗: $e')));
      }
    }
  }

  Future<void> _addToCart(String foodItemId) async {
    debugPrint('🛒 _addToCart() called with $foodItemId');
    final user = supa.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }

    try {
      // 1) 拿目前 user 的 cart 列表，並轉成 List<Map<String,dynamic>>
      final rawCarts = await supa
          .from('carts')
          .select('id')
          .eq('user_id', user.id);
      final List<Map<String, dynamic>> carts =
      List<Map<String, dynamic>>.from(rawCarts);

      // 2) 如果沒有，就新增一筆
      String cartId;
      if (carts.isEmpty) {
        final rawInserted = await supa
            .from('carts')
            .insert({'user_id': user.id})
            .select('id');
        final inserted = List<Map<String, dynamic>>.from(rawInserted);
        cartId = inserted.first['id'] as String;
        debugPrint('🆕 建立新 cart: $cartId');
      } else {
        cartId = carts.first['id'] as String;
        debugPrint('✅ 使用既有 cart: $cartId');
      }

      // 3) 拿這張 cart 裡，對應的 cart_item，同樣轉型
      final rawCi = await supa
          .from('cart_items')
          .select('quantity')
          .eq('cart_id', cartId)
          .eq('food_item_id', foodItemId);
      final List<Map<String, dynamic>> ciList =
      List<Map<String, dynamic>>.from(rawCi);

      // 4) update 或 insert
      if (ciList.isNotEmpty) {
        final int currentQty = ciList.first['quantity'] as int;
        await supa
            .from('cart_items')
            .update({'quantity': currentQty + 1})
            .eq('cart_id', cartId)
            .eq('food_item_id', foodItemId);
        debugPrint('🔄 更新 quantity: ${currentQty + 1}');
      } else {
        await supa.from('cart_items').insert({
          'cart_id': cartId,
          'food_item_id': foodItemId,
          'quantity': 1,
        });
        debugPrint('➕ 新增 cart_item (qty=1)');
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已加入購物車')));
    } catch (e, st) {
      debugPrint('❌ _addToCart 發生錯誤: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入購物車失敗：$e')));
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.restaurantName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _foodItems.isEmpty
          ? const Center(child: Text('此餐廳目前沒有商品'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _foodItems.length,
        itemBuilder: (context, index) {
          final item = _foodItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                    BorderRadius.circular(8.0),
                    child: (item['image_url']
                    as String?)
                        ?.isNotEmpty ??
                        false
                        ? Image.network(
                      item['image_url']
                      as String,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context,
                          error,
                          stackTrace) =>
                          Container(
                            width: 80,
                            height: 80,
                            color:
                            Colors.grey[300],
                            child: const Icon(
                                Icons
                                    .broken_image,
                                size: 40),
                          ),
                    )
                        : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(
                          Icons
                              .image_not_supported,
                          size: 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['description']
                          as String,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                            Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${item['price']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons
                              .shopping_cart),
                          label: const Text(
                              '加入購物車'),
                          onPressed: ()
                          {
                            debugPrint('🔥 _addToCart tapped, itemId=');
                            _addToCart(
                                item['id']
                                as String);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
