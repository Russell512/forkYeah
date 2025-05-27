// lib/cart_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  bool _isCheckingOut = false;
  List<Map<String, dynamic>> _cartItemsData = [];
  String? _userDefaultAddress;

  Map<String, dynamic>? _selectedCouponDetails;
  double _discountAmount = 0.0;
  double _originalTotalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCartAndUserInfo();
  }

  double _calculateOriginalTotal() {
    return _cartItemsData.fold<double>(0, (sum, item) {
      final qty = item['quantity'] as int;
      final foodData = item['food_items'] as Map<String, dynamic>?;
      if (foodData == null) return sum;
      final price = (foodData['price'] as num?)?.toDouble() ?? 0.0;
      return sum + price * qty;
    });
  }

  Future<void> _loadCartAndUserInfo() async {
    setState(() {
      _isLoading = true;
      // 考慮是否在每次載入時清除已選優惠券，這裡暫時不清除，
      // 讓用戶可以先選券再調整購物車
      // _selectedCouponDetails = null;
      // _discountAmount = 0.0;
    });
    final user = supa.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('請先登入')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      setState(() => _isLoading = false); // 確保isLoading更新
      return;
    }
    try {
      final userProfile = await supa.from('users').select('address').eq('id', user.id).maybeSingle();
      if (userProfile != null && userProfile['address'] != null) {
        _userDefaultAddress = userProfile['address'] as String;
      }
      final cartRes = await supa.from('carts').select('id').eq('user_id', user.id).maybeSingle();
      if (cartRes == null) {
        if (mounted) {
          setState(() { _cartItemsData = []; _originalTotalAmount = 0.0; _applyCouponLogic(); });
        }
        return;
      }
      final cartId = cartRes['id'] as String;
      final response = await supa
          .from('cart_items')
          .select('quantity, food_items(id, name, price, restaurant_id)')
          .eq('cart_id', cartId)
          .gt('quantity', 0);
      if (mounted) {
        setState(() {
          _cartItemsData = List<Map<String, dynamic>>.from(response);
          _originalTotalAmount = _calculateOriginalTotal();
          _applyCouponLogic();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入購物車失敗: $e')));
      }
    } finally {
        if(mounted){
            setState(() => _isLoading = false);
        }
    }
  }

  Future<void> _updateQuantity(String foodItemId, int newQty) async {
    if (_isCheckingOut) return;
    if (newQty <= 0) { await _deleteItem(foodItemId); return; }
    try {
      final user = supa.auth.currentUser;
      if (user == null) return;
      final cartRes = await supa.from('carts').select('id').eq('user_id', user.id).maybeSingle();
      if (cartRes == null) return;
      final cartId = cartRes['id'] as String;
      await supa
          .from('cart_items')
          .update({'quantity': newQty})
          .eq('cart_id', cartId)
          .eq('food_item_id', foodItemId);
      await _loadCartAndUserInfo();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新數量失敗：$e')));
    }
  }

  Future<void> _deleteItem(String foodItemId) async {
    if (_isCheckingOut) return;
    try {
      final user = supa.auth.currentUser;
      if (user == null) return;
      final cartRes = await supa.from('carts').select('id').eq('user_id', user.id).maybeSingle();
      if (cartRes == null) return;
      final cartId = cartRes['id'] as String;
      await supa
          .from('cart_items')
          .delete()
          .eq('cart_id', cartId)
          .eq('food_item_id', foodItemId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已從購物車移除')));
      await _loadCartAndUserInfo();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('移除商品失敗：$e')));
    }
  }

  void _applyCouponLogic() {
    _originalTotalAmount = _calculateOriginalTotal();
    double currentDiscount = 0.0;
    if (_selectedCouponDetails != null) {
      final couponType = _selectedCouponDetails!['coupon_type'] as String?;
      final couponLabel = _selectedCouponDetails!['label'] as String? ?? '';

      if (couponType == 'permanent_free_meal' || couponType == 'free_meal' || couponLabel.contains('老闆請客') || couponLabel.contains('一輩子免費')) {
        currentDiscount = _originalTotalAmount;
      } else if (couponType == 'discount_amount' || couponLabel.contains('折抵')) {
        currentDiscount = 300.0; // 固定折扣 300
      }
    }
    _discountAmount = (currentDiscount > _originalTotalAmount && _originalTotalAmount > 0) ? _originalTotalAmount : currentDiscount;
     // 如果原始總金額是0，折扣也應該是0，除非是負折扣（不常見）
    if (_originalTotalAmount <= 0) _discountAmount = 0;


    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _navigateToMyCoupons() async {
    if (_isCheckingOut) return;
    final result = await Navigator.pushNamed(context, '/my_coupons');

    if (result != null && result is Map<String, dynamic>) {
      if (mounted) {
        setState(() {
          _selectedCouponDetails = result;
          _applyCouponLogic();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已選用優惠券: ${_selectedCouponDetails!['label']}')),
        );
      }
    }
  }

  Future<void> _removeAppliedCoupon() {
    setState(() {
      _selectedCouponDetails = null;
      _discountAmount = 0.0;
      _applyCouponLogic(); // 移除後也需要重新計算總金額
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已移除選用的優惠券')),
    );
    return Future.value();
  }

  Future<void> _checkout() async {
    if (_cartItemsData.isEmpty || _isCheckingOut) return;
    setState(() => _isCheckingOut = true);
    final user = supa.auth.currentUser;
    if (user == null) { /* ... */ return; }

    // 最終支付金額在前端計算好
    final double finalAmountToPay = _originalTotalAmount - _discountAmount;

    final Map<String, List<Map<String, dynamic>>> itemsByRestaurant = {};
    for (var cartItem in _cartItemsData) {
      final foodItemDetails = cartItem['food_items'] as Map<String, dynamic>;
      final restaurantId = foodItemDetails['restaurant_id'] as String?;
      if (restaurantId == null) { /* ... */ return; }
      itemsByRestaurant.putIfAbsent(restaurantId, () => []).add(cartItem);
    }

    // 準備傳遞給 RPC 的參數 (不修改後端版本)
    final checkoutParams = {
        'p_user_id': user.id,
        'p_order_total_amount': finalAmountToPay, // <--- 將折扣後的最終金額作為訂單總額傳遞
        'p_delivery_address': _userDefaultAddress ?? '用戶未提供地址',
        'p_notes': _selectedCouponDetails != null
            ? '來自App的訂單 (使用優惠券: ${_selectedCouponDetails!['label']}, 原價: \$${_originalTotalAmount.toStringAsFixed(2)}, 折扣: \$${_discountAmount.toStringAsFixed(2)})'
            : '來自App的訂單', // 在備註中記錄優惠券使用情況
        'p_restaurants_data': itemsByRestaurant.entries.map((entry) {
          final restaurantId = entry.key;
          final restaurantCartItems = entry.value;
          // 這裡的 sub_total_amount 仍然是該餐廳商品的原始小計，
          // 或者你可以按比例分配總折扣到各個子訂單，但這會更複雜。
          // 為了簡單，我們先讓子訂單金額保持原始值，總訂單金額是折扣後的。
          final restaurantSubTotal = restaurantCartItems.fold<double>(0, (sum, item) {
            final qty = item['quantity'] as int;
            final foodItemDetails = item['food_items'] as Map<String, dynamic>;
            final price = (foodItemDetails['price'] as num).toDouble();
            return sum + price * qty;
          });
          return {
            'restaurant_id': restaurantId,
            'sub_total_amount': restaurantSubTotal, // 子訂單金額保持原始
            'order_items_data': restaurantCartItems.map((cartItem) {
              final foodItemDetails = cartItem['food_items'] as Map<String, dynamic>;
              return {
                'food_item_id': foodItemDetails['id'] as String,
                'quantity': cartItem['quantity'] as int,
                'unit_price': (foodItemDetails['price'] as num).toDouble(),
                'item_total_price': (foodItemDetails['price'] as num).toDouble() * (cartItem['quantity'] as int)
              };
            }).toList()
          };
        }).toList()
      };

    debugPrint("Calling RPC 'process_checkout' with params: $checkoutParams");

    try {
      final dynamic rpcResponse = await supa.rpc('process_checkout', params: checkoutParams);
      debugPrint("RPC 'process_checkout' response: $rpcResponse");

      if (rpcResponse != null && rpcResponse is String) {
        final orderId = rpcResponse;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('訂單已成功提交！訂單ID: $orderId')),
          );
          setState(() {
            _selectedCouponDetails = null;
            _discountAmount = 0.0;
          });
          _loadCartAndUserInfo();
        }
      } else {
         throw Exception('結帳過程失敗，後端函數未成功返回訂單ID。請檢查數據庫日誌。');
      }
    } catch (e) {
      debugPrint('結帳失敗 (catch block): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('結帳失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalTotalAfterDiscount = (_originalTotalAmount - _discountAmount).clamp(0, double.infinity); // 確保最終金額不為負

    return Scaffold(
      appBar: AppBar(title: const Text('我的購物車')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItemsData.isEmpty && _selectedCouponDetails == null
              ? const Center(child: Text('購物車內沒有商品'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: _cartItemsData.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, index) {
                          final cartItem = _cartItemsData[index];
                          final foodData = cartItem['food_items'] as Map<String, dynamic>?;
                          if (foodData == null) return const ListTile(title: Text('商品資料錯誤'));
                          final foodName = foodData['name'] as String? ?? '未知商品';
                          final foodId = foodData['id'] as String;
                          final qty = cartItem['quantity'] as int;
                          final price = (foodData['price'] as num?)?.toDouble() ?? 0.0;
                          final subTotal = price * qty;

                          return ListTile(
                            title: Text(foodName),
                            subtitle: Text('\$${price.toStringAsFixed(2)} × $qty ＝ \$${subTotal.toStringAsFixed(2)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: _isCheckingOut ? null : () => _updateQuantity(foodId, qty - 1)),
                                Text(qty.toString()),
                                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _isCheckingOut ? null : () => _updateQuantity(foodId, qty + 1)),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _isCheckingOut ? null : () => _deleteItem(foodId)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_userDefaultAddress != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text("送餐地址: $_userDefaultAddress", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ),

                          if (_selectedCouponDetails == null && _cartItemsData.isNotEmpty) // 只有購物車非空且未選券時顯示
                            OutlinedButton.icon(
                              icon: const Icon(Icons.local_offer_outlined),
                              label: const Text('選擇可使用的優惠券'),
                              onPressed: _navigateToMyCoupons,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Theme.of(context).primaryColor),
                                foregroundColor: Theme.of(context).primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            )
                          else if (_selectedCouponDetails != null)
                            Card(
                              elevation: 1,
                              color: Colors.green.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('已選用: ${_selectedCouponDetails!['label']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                          if (_discountAmount > 0)
                                            Text('折扣金額: \$${_discountAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.redAccent, size: 20),
                                      onPressed: _removeAppliedCoupon,
                                      tooltip: '移除優惠券',
                                    )
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),

                          if (_selectedCouponDetails != null && _discountAmount > 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('商品原總計:', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                Text('\$${_originalTotalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('優惠券折扣:', style: TextStyle(fontSize: 16, color: Colors.green)),
                                Text('-\$${_discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.green)),
                              ],
                            ),
                            const Divider(height: 16),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('最終應付金額：', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('\$${finalTotalAfterDiscount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: _isCheckingOut ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.payment),
                            label: Text(_isCheckingOut ? '處理中...' : '確認結帳'),
                            onPressed: (_cartItemsData.isEmpty || _isCheckingOut) ? null : _checkout,
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}