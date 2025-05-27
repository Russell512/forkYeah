// lib/my_orders_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// 輔助函數 (如果沒有放在共享 utils 文件中)
String formatOrderStatusForMyOrders(String? status) {
  switch (status) {
    case 'assigned_delivering': return '運送中';
    case 'delivered': return '已送達';
    default: return status ?? '未知';
  }
}
Color getOrderStatusColorForMyOrders(String? status) {
  switch (status) {
    case 'assigned_delivering': return Colors.teal.shade300;
    case 'delivered': return Colors.green.shade400;
    default: return Colors.grey.shade400;
  }
}

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});
  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  List<Map<String, dynamic>> _deliveringSubOrders = [];
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = supa.auth.currentUser;
    if (_currentUser == null) {
      _handleUnauthenticatedUser();
    } else {
      _loadDeliveringSubOrders();
    }
  }

  void _handleUnauthenticatedUser() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入外送員帳號')));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDeliveringSubOrders() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await supa
          .from('restaurant_orders')
          .select('''
            id, 
            status, 
            sub_total_amount, 
            created_at,
            updated_at, 
            restaurant_id, 
            users!restaurant_orders_restaurant_id_fkey (name, phone), 
            order_id,
            orders (delivery_address, notes, users!orders_user_id_fkey(name, phone)) 
          ''')
          .eq('delivery_id', _currentUser!.id)
          .eq('status', 'assigned_delivering')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _deliveringSubOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入配送中訂單失敗: $e')));
        setState(() => _isLoading = false);
      }
      debugPrint("Error loading delivering sub-orders: $e");
    }
  }

  // 外送員將訂單標記為「已送達」並嘗試歸檔
  Future<void> _markAsDelivered(String restaurantOrderId, String mainOrderId) async { // <--- 重新加入 mainOrderId 參數
    if (_currentUser == null || _isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      // 1. 更新子訂單狀態為 'delivered'
      await supa
          .from('restaurant_orders')
          .update({'status': 'delivered'})
          .eq('id', restaurantOrderId)
          .eq('delivery_id', _currentUser!.id)
          .eq('status', 'assigned_delivering');

      debugPrint("Sub-order $restaurantOrderId marked as delivered.");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('訂單已標記為送達！正在嘗試歸檔主訂單...')),
        );
        debugPrint("Attempting to archive main order ID: $mainOrderId");

        // 2. 嘗試調用歸檔函數
        try {
          final dynamic rpcResponse = await supa.rpc('archive_completed_order', params: {'p_order_id': mainOrderId});
          debugPrint("RPC 'archive_completed_order' response for $mainOrderId: $rpcResponse");

          if (rpcResponse == true) {
            debugPrint("Main order $mainOrderId successfully archived via RPC.");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('主訂單已成功歸檔。')),
            );
          } else if (rpcResponse == false) {
            debugPrint("Main order $mainOrderId not archived (either not all sub-orders finalized or RPC returned false). Check database logs for notices from archive_completed_order function.");
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('主訂單尚未完全結束或歸檔條件未滿足。')),
            );
          } else { // rpcResponse is null or unexpected
            debugPrint("Archive RPC for main order $mainOrderId returned an unexpected value or null: $rpcResponse. This indicates an error within the SQL function or the RPC call itself. Check database logs for WARNINGS from archive_completed_order function.");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('訂單歸檔失敗或狀態未知，請檢查後台日誌。')),
            );
          }
        } catch (rpcError) { // RPC 調用本身拋出異常
          debugPrint("Error calling archive_completed_order RPC for main order $mainOrderId: $rpcError");
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('訂單已送達，但自動歸檔時發生錯誤: $rpcError')),
            );
          }
        }
        // 無論歸檔是否成功，都重新載入配送中訂單列表
        // 已送達的訂單（因為 status 變了）將不再顯示
        // 如果歸檔成功且活躍訂單被刪除，那更好
        _loadDeliveringSubOrders();
      }
    } catch (e) { // 更新子訂單狀態為 delivered 時的錯誤
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新訂單狀態為「已送達」失敗: $e')));
      }
      debugPrint("Error marking order $restaurantOrderId as delivered: $e");
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _notifyCustomerArrived(String restaurantOrderId, String customerName) async {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已模擬提醒顧客 $customerName 取餐 (訂單 #${restaurantOrderId.substring(0,6)}...)')),
        );
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('配送中訂單')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deliveringSubOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('目前沒有正在配送的訂單。'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新整理'),
                        onPressed: _loadDeliveringSubOrders,
                      )
                    ],
                  )
                )
              : RefreshIndicator(
                  onRefresh: _loadDeliveringSubOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _deliveringSubOrders.length,
                    itemBuilder: (context, index) {
                      final subOrder = _deliveringSubOrders[index];
                      final subOrderId = subOrder['id'] as String;
                      final mainOrderId = subOrder['order_id'] as String?; // <--- 從數據中獲取 mainOrderId
                                                                        // 確保 _loadDeliveringSubOrders 的 select 中有 order_id
                      final status = subOrder['status'] as String?;
                      final updatedAt = DateTime.parse(subOrder['updated_at'] as String);
                      final restaurantData = subOrder['users!restaurant_orders_restaurant_id_fkey'] as Map<String, dynamic>?;
                      final restaurantName = restaurantData?['name'] as String? ?? '未知餐廳';
                      final restaurantPhone = restaurantData?['phone'] as String?;
                      final mainOrderData = subOrder['orders'] as Map<String, dynamic>?;
                      final deliveryAddress = mainOrderData?['delivery_address'] as String? ?? '地址未提供';
                      final customerNotes = mainOrderData?['notes'] as String?;
                      final customerContactData = mainOrderData?['users!orders_user_id_fkey'] as Map<String, dynamic>?;
                      final customerName = customerContactData?['name'] as String? ?? '顧客';
                      final customerPhone = customerContactData?['phone'] as String?;
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
                              Row( /* ... (訂單號和狀態 Chip) ... */
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text('訂單 #${subOrderId.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                  Chip(label: Text(formatOrderStatusForMyOrders(status), style: const TextStyle(color: Colors.white, fontSize: 12)), backgroundColor: getOrderStatusColorForMyOrders(status)),
                                ],
                              ),
                              const Divider(height:12, thickness: 0.5),
                              Text('取餐餐廳: $restaurantName', style: const TextStyle(fontWeight: FontWeight.w500)),
                              if (restaurantPhone != null) Text('餐廳電話: $restaurantPhone'),
                              const SizedBox(height: 8),
                              Text('送至: $deliveryAddress', style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text('收件人: $customerName'),
                              if (customerPhone != null) Text('顧客電話: $customerPhone'),
                              if (customerNotes != null && customerNotes.isNotEmpty)
                                Padding(padding: const EdgeInsets.only(top:4.0), child: Text('顧客備註: $customerNotes', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey))),
                              Text('接單時間: ${DateFormat('MM-dd HH:mm').format(updatedAt.toLocal())}'),
                              const Divider(height: 16, thickness: 0.5),
                              const Text('商品項目:', style: TextStyle(fontWeight: FontWeight.w500)),
                              if (orderItems.isEmpty) const Text(' - 無商品項目資訊', style: TextStyle(fontStyle: FontStyle.italic)),
                              ...orderItems.map((item) {
                                final foodDetails = item['food_items'] as Map<String, dynamic>?;
                                final itemName = foodDetails?['name'] as String? ?? '未知商品';
                                final quantity = item['quantity'] as int;
                                return Text(' - $itemName × $quantity');
                              }).toList(),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                                    label: const Text('提醒顧客'),
                                    style: OutlinedButton.styleFrom(side: BorderSide(color: Theme.of(context).primaryColor), foregroundColor: Theme.of(context).primaryColor),
                                    onPressed: _isUpdatingStatus ? null : () => _notifyCustomerArrived(subOrderId, customerName),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: _isUpdatingStatus ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle, size: 20),
                                    label: const Text('完成配送'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    onPressed: (_isUpdatingStatus || mainOrderId == null || mainOrderId.isEmpty) // <--- 確保 mainOrderId 有效
                                                ? null 
                                                : () => _markAsDelivered(subOrderId, mainOrderId),
                                  ),
                                ],
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