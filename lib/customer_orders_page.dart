// lib/customer_orders_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // <--- 確保 intl 套件已安裝並引入

// 輔助函數，將 order_status_enum 轉換為用戶友好的文字
// 這些函數現在只定義一次
String _formatOrderStatusForDisplay(String? status) { // 改名以避免與其他可能的同名函數衝突
  switch (status) {
    case 'pending_payment':
      return '等待付款';
    case 'pending_confirmation':
      return '等待店家確認';
    case 'confirmed_processing':
      return '店家已確認，製作中';
    case 'ready_for_pickup':
      return '餐點已準備好';
    case 'assigned_delivering':
      return '外送員運送中';
    case 'delivered':
      return '已送達';
    case 'cancelled_by_customer':
      return '已取消 (由您取消)';
    case 'cancelled_by_restaurant':
      return '已取消 (店家取消)';
    case 'completed':
      return '訂單已完成';
    default:
      return status ?? '未知狀態'; // 確保總是有返回值
  }
}

Color _getOrderStatusColorForDisplay(String? status) { // 改名以避免與其他可能的同名函數衝突
  switch (status) {
    case 'pending_confirmation':
      return Colors.orange.shade300;
    case 'confirmed_processing':
      return Colors.blue.shade300;
    case 'ready_for_pickup':
      return Colors.lightGreen.shade400;
    case 'assigned_delivering':
      return Colors.teal.shade300;
    case 'delivered':
    case 'completed':
      return Colors.green.shade400;
    case 'cancelled_by_customer':
    case 'cancelled_by_restaurant':
      return Colors.red.shade300;
    default:
      return Colors.grey.shade400; // 確保總是有返回值
  }
}

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({super.key});

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _customerOrders = [];

  @override
  void initState() {
    super.initState();
    _loadCustomerOrders();
  }

  Future<void> _loadCustomerOrders() async {
    setState(() => _isLoading = true);
    final user = supa.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      setState(() => _isLoading = false); // 確保 isLoading 被重置
      return;
    }

    try {
      final ordersResponse = await supa
          .from('orders')
          .select('id, total_amount, created_at, delivery_address, notes, restaurant_orders(id, restaurant_id, status, sub_total_amount, users!restaurant_orders_restaurant_id_fkey(name))')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _customerOrders = List<Map<String, dynamic>>.from(ordersResponse);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入訂單失敗: $e')));
      }
      debugPrint("Error loading customer orders: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String getOverallOrderStatus(List<dynamic> restaurantOrders) {
    if (restaurantOrders.isEmpty) return '無子訂單';
    Set<String> statuses = restaurantOrders.map((ro) => ro['status'] as String? ?? '').toSet();
    statuses.removeWhere((s) => s.isEmpty); // 移除可能的空狀態

    if (statuses.isEmpty) return '狀態未知';
    if (statuses.every((s) => s == 'delivered' || s == 'completed')) return '已完成';
    if (statuses.contains('cancelled_by_restaurant') || statuses.contains('cancelled_by_customer')) return '部分或全部已取消';
    if (statuses.contains('assigned_delivering')) return '運送中';
    if (statuses.contains('ready_for_pickup')) return '部分餐點已準備好';
    if (statuses.contains('confirmed_processing')) return '店家處理中';
    if (statuses.every((s) => s == 'pending_confirmation')) return '等待店家確認';
    return '處理中';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的訂單')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customerOrders.isEmpty
              ? Center(
                  child: Column( // 添加刷新按鈕以便在無訂單時也能刷新
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('您目前沒有任何訂單。'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新整理'),
                        onPressed: _loadCustomerOrders,
                      )
                    ],
                  )
                )
              : RefreshIndicator(
                  onRefresh: _loadCustomerOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _customerOrders.length,
                    itemBuilder: (context, index) {
                      final order = _customerOrders[index];
                      final orderId = order['id'] as String;
                      final totalAmount = (order['total_amount'] as num).toDouble();
                      final createdAt = DateTime.parse(order['created_at'] as String);
                      final restaurantOrdersRaw = order['restaurant_orders'] as List<dynamic>? ?? [];
                      final overallStatus = getOverallOrderStatus(restaurantOrdersRaw);
                      final firstSubOrderStatus = restaurantOrdersRaw.isNotEmpty ? restaurantOrdersRaw.first['status'] as String? : null;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/customer_order_detail',
                              arguments: {'order_id': orderId},
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded( // 讓訂單號可以換行如果太長
                                      child: Text(
                                        '訂單 #${orderId.substring(0, 8)}...',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(overallStatus, style: const TextStyle(fontSize: 12, color: Colors.white)),
                                      backgroundColor: _getOrderStatusColorForDisplay(firstSubOrderStatus),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '總金額: \$${totalAmount.toStringAsFixed(2)}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14)
                                ),
                                Text(
                                  '下單時間: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toLocal())}', // DateFormat 現在應該可以被識別
                                   style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    child: const Text('查看詳情 >', style: TextStyle(color: Colors.green)),
                                    onPressed: () {
                                       Navigator.pushNamed(
                                        context,
                                        '/customer_order_detail',
                                        arguments: {'order_id': orderId},
                                      );
                                    },
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}