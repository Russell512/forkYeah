// lib/restaurant_active_orders_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // 用於日期格式化

// 我們可以複用顧客端的訂單狀態格式化和顏色函數
// 理想情況下，這些應該放在一個共享的 utils 檔案中
String formatOrderStatusForRestaurant(String? status) {
  switch (status) {
    case 'pending_confirmation': return '待確認';
    case 'confirmed_processing': return '製作中';
    case 'ready_for_pickup': return '待取餐';
    // 餐廳端可能不需要看到所有顧客端的狀態
    default: return status ?? '未知';
  }
}

Color getOrderStatusColorForRestaurant(String? status) {
  switch (status) {
    case 'pending_confirmation': return Colors.orange.shade300;
    case 'confirmed_processing': return Colors.blue.shade300;
    case 'ready_for_pickup': return Colors.lightGreen.shade400;
    default: return Colors.grey.shade400;
  }
}


class RestaurantActiveOrdersPage extends StatefulWidget {
  const RestaurantActiveOrdersPage({super.key});

  @override
  State<RestaurantActiveOrdersPage> createState() => _RestaurantActiveOrdersPageState();
}

class _RestaurantActiveOrdersPageState extends State<RestaurantActiveOrdersPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeOrders = []; // 存儲 restaurant_orders

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = supa.auth.currentUser;
    if (_currentUser == null) {
      // 處理未登入情況，理論上 Drawer 不會顯示此選項給未登入用戶
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入餐廳帳號')));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } else {
      _loadActiveOrders();
    }
  }

  Future<void> _loadActiveOrders() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      // 查詢分配給當前餐廳 (currentUser.id) 的，且狀態是 'pending_confirmation' 或 'confirmed_processing' 的子訂單
      // 同時獲取主訂單的創建時間和顧客資訊 (如果需要)
      // 以及該子訂單下的商品項
      final response = await supa
          .from('restaurant_orders')
          .select('''
            id, 
            status, 
            sub_total_amount, 
            created_at,
            order_id, 
            orders ( user_id, users (name, phone, address, county, district) ), 
            order_items ( id, quantity, unit_price, item_total_price, food_items (name) )
          ''')
          .eq('restaurant_id', _currentUser!.id)
          .in_('status', ['pending_confirmation', 'confirmed_processing', 'ready_for_pickup']) // 也顯示已準備好的，方便查看
          .order('created_at', ascending: true); // 優先處理較早的訂單

      if (mounted) {
        setState(() {
          _activeOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入訂單失敗: $e')));
        setState(() => _isLoading = false);
      }
      debugPrint("Error loading active orders for restaurant: $e");
    }
  }

  Future<void> _updateOrderStatus(String restaurantOrderId, String newStatus) async {
    if (_currentUser == null) return;
    // 可以添加一個 _isUpdating 狀態來防止重複點擊
    // setState(() => _isUpdating = true);

    try {
      await supa
          .from('restaurant_orders')
          .update({'status': newStatus})
          .eq('id', restaurantOrderId)
          .eq('restaurant_id', _currentUser!.id); // 確保只更新自己餐廳的訂單

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('訂單狀態已更新為: ${formatOrderStatusForRestaurant(newStatus)}')),
        );
        _loadActiveOrders(); // 重新載入列表
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新訂單狀態失敗: $e')));
      }
      debugPrint("Error updating order status: $e");
    } finally {
      // if (mounted) setState(() => _isUpdating = false);
    }
  }

  Widget _buildActionButtons(Map<String, dynamic> subOrder) {
    final currentStatus = subOrder['status'] as String?;
    List<Widget> buttons = [];

    if (currentStatus == 'pending_confirmation') {
      buttons.add(ElevatedButton(
        onPressed: () => _updateOrderStatus(subOrder['id'] as String, 'confirmed_processing'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text('接受訂單', style: TextStyle(color: Colors.white)),
      ));
      buttons.add(const SizedBox(width: 8));
      buttons.add(ElevatedButton( // 拒絕訂單 (可選)
        onPressed: () => _updateOrderStatus(subOrder['id'] as String, 'cancelled_by_restaurant'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('拒絕訂單', style: TextStyle(color: Colors.white)),
      ));
    } else if (currentStatus == 'confirmed_processing') {
      buttons.add(ElevatedButton(
        onPressed: () => _updateOrderStatus(subOrder['id'] as String, 'ready_for_pickup'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        child: const Text('完成製作', style: TextStyle(color: Colors.white)),
      ));
    } else if (currentStatus == 'ready_for_pickup') {
      // 通常這個狀態是給外送員看的，但餐廳也可以查看
       buttons.add(const Chip(label: Text('等待外送員取餐'), backgroundColor: Colors.lightGreen));
    }

    return Wrap(spacing: 8.0, runSpacing: 4.0, children: buttons);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('餐廳待處理訂單')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('目前沒有待處理的訂單。'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新整理'),
                        onPressed: _loadActiveOrders,
                      )
                    ],
                  )
                )
              : RefreshIndicator(
                  onRefresh: _loadActiveOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _activeOrders.length,
                    itemBuilder: (context, index) {
                      final subOrder = _activeOrders[index];
                      final subOrderId = subOrder['id'] as String;
                      final status = subOrder['status'] as String?;
                      final subTotal = (subOrder['sub_total_amount'] as num).toDouble();
                      final createdAt = DateTime.parse(subOrder['created_at'] as String);

                      // 獲取顧客資訊 (如果需要顯示)
                      final orderData = subOrder['orders'] as Map<String, dynamic>?;
                      final customerData = orderData?['users'] as Map<String, dynamic>?;
                      final customerName = customerData?['name'] as String? ?? '顧客';
                      // final customerPhone = customerData?['phone'] as String?; // 如果需要

                      final orderItems = List<Map<String, dynamic>>.from(subOrder['order_items'] ?? []);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '訂單 #${subOrderId.substring(0, 8)} (來自 $customerName)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Chip(
                                    label: Text(
                                      formatOrderStatusForRestaurant(status),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                    backgroundColor: getOrderStatusColorForRestaurant(status),
                                  ),
                                ],
                              ),
                              Text('金額: \$${subTotal.toStringAsFixed(2)}'),
                              Text('下單時間: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toLocal())}'),
                              const Divider(height: 16),
                              const Text('商品項目:', style: TextStyle(fontWeight: FontWeight.w500)),
                              if (orderItems.isEmpty)
                                const Text(' - 無商品項目資訊', style: TextStyle(fontStyle: FontStyle.italic)),
                              ...orderItems.map((item) {
                                final foodDetails = item['food_items'] as Map<String, dynamic>?;
                                final itemName = foodDetails?['name'] as String? ?? '未知商品';
                                final quantity = item['quantity'] as int;
                                return Text(' - $itemName × $quantity');
                              }).toList(),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _buildActionButtons(subOrder),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}