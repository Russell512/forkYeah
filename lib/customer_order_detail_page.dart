// lib/customer_order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // <--- 確保 intl 套件已安裝並引入

// 從 customer_orders_page.dart 複製或共享的輔助函數
// 或者更好的做法是將它們放到一個公共的 utils/helpers.dart 檔案中
String _formatOrderStatusForDisplayInDetail(String? status) { // 改名以避免衝突
  switch (status) {
    case 'pending_payment': return '等待付款';
    case 'pending_confirmation': return '等待店家確認';
    case 'confirmed_processing': return '店家已確認，製作中';
    case 'ready_for_pickup': return '餐點已準備好';
    case 'assigned_delivering': return '外送員運送中';
    case 'delivered': return '已送達';
    case 'cancelled_by_customer': return '已取消 (由您取消)';
    case 'cancelled_by_restaurant': return '已取消 (店家取消)';
    case 'completed': return '訂單已完成';
    default: return status ?? '未知狀態';
  }
}

Color _getOrderStatusColorForDisplayInDetail(String? status) { // 改名以避免衝突
  switch (status) {
    case 'pending_confirmation': return Colors.orange.shade300;
    case 'confirmed_processing': return Colors.blue.shade300;
    case 'ready_for_pickup': return Colors.lightGreen.shade400;
    case 'assigned_delivering': return Colors.teal.shade300;
    case 'delivered': case 'completed': return Colors.green.shade400;
    case 'cancelled_by_customer': case 'cancelled_by_restaurant': return Colors.red.shade300;
    default: return Colors.grey.shade400;
  }
}

class CustomerOrderDetailPage extends StatefulWidget {
  final String orderId;

  const CustomerOrderDetailPage({super.key, required this.orderId});

  @override
  State<CustomerOrderDetailPage> createState() => _CustomerOrderDetailPageState();
}

class _CustomerOrderDetailPageState extends State<CustomerOrderDetailPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _orderData;
  List<Map<String, dynamic>> _restaurantOrdersData = [];

  @override
  void initState() {
    super.initState();
    _loadOrderDetail();
  }

  Future<void> _loadOrderDetail() async {
    setState(() => _isLoading = true);
    try {
      final orderResponse = await supa
          .from('orders')
          .select('id, total_amount, created_at, delivery_address, notes')
          .eq('id', widget.orderId)
          .single();

      final restaurantOrdersResponse = await supa
          .from('restaurant_orders')
          .select('id, restaurant_id, status, sub_total_amount, users!restaurant_orders_restaurant_id_fkey(name), order_items(id, quantity, unit_price, item_total_price, food_items(name, image_url))')
          .eq('order_id', widget.orderId);

      if (mounted) {
        setState(() {
          _orderData = Map<String, dynamic>.from(orderResponse);
          _restaurantOrdersData = List<Map<String, dynamic>>.from(restaurantOrdersResponse);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入訂單詳情失敗: $e')));
      }
      debugPrint("Error loading order detail: $e");
    } finally {
        if(mounted){
            setState(() => _isLoading = false);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('訂單詳情')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_orderData == null) {
      return Scaffold(appBar: AppBar(title: const Text('訂單詳情')), body: const Center(child: Text('找不到訂單資訊。')));
    }

    final order = _orderData!;
    final totalAmount = (order['total_amount'] as num).toDouble();
    final createdAt = DateTime.parse(order['created_at'] as String);
    final deliveryAddress = order['delivery_address'] as String?;
    final notes = order['notes'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text('訂單 #${widget.orderId.substring(0, 8)}...')),
      body: RefreshIndicator(
        onRefresh: _loadOrderDetail,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('訂單總覽', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Divider(height: 20, thickness: 1),
              _buildDetailRow("訂單編號:", widget.orderId),
              _buildDetailRow("下單時間:", DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt.toLocal())), // DateFormat
              _buildDetailRow("總金額:", "\$${totalAmount.toStringAsFixed(2)}"),
              if (deliveryAddress != null && deliveryAddress.isNotEmpty)
                _buildDetailRow("送餐地址:", deliveryAddress),
              if (notes != null && notes.isNotEmpty)
                _buildDetailRow("訂單備註:", notes),

              const SizedBox(height: 24),
              Text('各餐廳訂單詳情', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Divider(height: 20, thickness: 1),

              if (_restaurantOrdersData.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("此訂單沒有詳細的餐廳訂單項目。", style: TextStyle(color: Colors.grey)),
                ),

              ..._restaurantOrdersData.map((subOrder) {
                final restaurantName = (subOrder['users'] as Map<String,dynamic>?)?['name'] as String? ?? '未知餐廳';
                final subOrderStatus = subOrder['status'] as String?;
                final subOrderAmount = (subOrder['sub_total_amount'] as num).toDouble();
                final orderItems = List<Map<String, dynamic>>.from(subOrder['order_items'] ?? []);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                restaurantName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              label: Text(
                                _formatOrderStatusForDisplayInDetail(subOrderStatus),
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                              backgroundColor: _getOrderStatusColorForDisplayInDetail(subOrderStatus),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        Text('小計: \$${subOrderAmount.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700)),
                        const Divider(height: 16, thickness: 0.5),
                        Text("商品項目:", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        const SizedBox(height: 4),
                        if (orderItems.isEmpty)
                          const Text(" - 此餐廳訂單無商品項目。", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        ...orderItems.map((item) {
                          final foodDetails = item['food_items'] as Map<String, dynamic>?;
                          final itemName = foodDetails?['name'] as String? ?? '未知商品';
                          final quantity = item['quantity'] as int;
                          final unitPrice = (item['unit_price'] as num).toDouble();
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text("$itemName × $quantity"),
                            trailing: Text("\$${(unitPrice * quantity).toStringAsFixed(2)}"),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87, fontSize: 14))),
        ],
      ),
    );
  }
}