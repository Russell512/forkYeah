// lib/restaurant_order_history_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// 輔助函數 (可以共享或重新定義)
String formatRestaurantReceiptStatus(String? status) {
  switch (status) {
    case 'completed': return '已完成';
    case 'delivered': return '已送達';
    case 'cancelled_by_customer': return '顧客取消';
    case 'cancelled_by_restaurant': return '本店取消';
    default: return status ?? '未知狀態';
  }
}
Color getRestaurantReceiptStatusColor(String? status) {
  switch (status) {
    case 'completed':
    case 'delivered':
      return Colors.green.shade400;
    case 'cancelled_by_customer':
    case 'cancelled_by_restaurant':
      return Colors.red.shade300;
    default:
      return Colors.grey.shade400;
  }
}

class RestaurantOrderHistoryPage extends StatefulWidget {
  const RestaurantOrderHistoryPage({super.key});

  @override
  State<RestaurantOrderHistoryPage> createState() => _RestaurantOrderHistoryPageState();
}

class _RestaurantOrderHistoryPageState extends State<RestaurantOrderHistoryPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _receiptSubOrders = []; // 存儲已歸檔的子訂單 (receipt_restaurant_orders)
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = supa.auth.currentUser;
    if (_currentUser == null) {
      _handleUnauthenticatedUser();
    } else {
      _loadRestaurantReceipts();
    }
  }

   void _handleUnauthenticatedUser() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入餐廳帳號')));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadRestaurantReceipts() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      // 查詢屬於當前餐廳 (restaurant_id = _currentUser!.id) 的已歸檔子訂單
      // 同時獲取顧客資訊和商品項
      // 注意：嵌套查詢 users!fk_... 和 receipt_items(...) 依賴正確的外鍵
      // 你需要替換 users! 的外鍵提示名稱為 receipt_restaurant_orders.delivery_id 指向 users.id 的實際名稱 (用於獲取外送員信息，如果需要的話)
      // 以及 receipt_restaurant_orders.receipt_id 指向 receipts.id (用於獲取顧客和主訂單信息)
      const String deliveryUserForeignKeyHint = 'delivery_user:users!receipt_restaurant_orders_delivery_id_fkey'; // <--- 替換為 actual fk name for delivery_id -> users
      const String mainReceiptForeignKeyHint = 'main_receipt:receipts!receipt_restaurant_orders_receipt_id_fkey'; // <--- 替換為 actual fk name for receipt_restaurant_orders.receipt_id -> receipts

      final response = await supa
          .from('receipt_restaurant_orders')
          .select('''
            id, 
            restaurant_id, 
            delivery_id, 
            final_status, 
            sub_total_amount, 
            original_created_at, 
            archived_at,
            $deliveryUserForeignKeyHint(name, phone),
            $mainReceiptForeignKeyHint (
               user_id, 
               delivery_address, 
               notes, 
               users!receipts_user_id_fkey (name, phone) 
            ),
            receipt_items ( 
              food_item_name, 
              food_item_image_url, 
              quantity, 
              unit_price, 
              item_total_price 
            )
          ''')
          .eq('restaurant_id', _currentUser!.id) // 只查詢屬於當前餐廳的
          // 可以根據需要添加篩選條件，例如只顯示已完成的 'completed' 或 'delivered' 狀態的
          // .in_('final_status', ['completed', 'delivered', 'cancelled_by_restaurant'])
          .order('archived_at', ascending: false); // 按歸檔時間降序排列

      if (mounted) {
        setState(() {
          _receiptSubOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入歷史訂單失敗: $e')));
        setState(() => _isLoading = false);
      }
      debugPrint("Error loading restaurant receipts: $e");
    }
  }

  // 輔助函數來顯示歷史子訂單詳情 (類似顧客端)
  void _showReceiptSubOrderDetailDialog(Map<String, dynamic> receiptSubOrder) {
    final subOrderId = receiptSubOrder['id'] as String;
    final subOrderStatus = receiptSubOrder['final_status'] as String?;
    final subTotal = (receiptSubOrder['sub_total_amount'] as num).toDouble();
    final originalCreatedAt = receiptSubOrder['original_created_at'] != null ? DateTime.parse(receiptSubOrder['original_created_at'] as String) : null;
    final archivedAt = DateTime.parse(receiptSubOrder['archived_at'] as String);

    // 從嵌套查詢中獲取數據
    final mainReceiptData = receiptSubOrder['main_receipt'] as Map<String, dynamic>?;
    final deliveryAddress = mainReceiptData?['delivery_address'] as String? ?? '地址未提供';
    final customerNotes = mainReceiptData?['notes'] as String?;
    final customerData = mainReceiptData?['users'] as Map<String, dynamic>?; // 來自 main_receipts 嵌套的 users
    final customerName = customerData?['name'] as String? ?? '顧客';
    final customerPhone = customerData?['phone'] as String?;

    final deliveryUserData = receiptSubOrder['delivery_user'] as Map<String, dynamic>?; // 來自 delivery_user 嵌套
    final deliveryUserName = deliveryUserData?['name'] as String? ?? '未指定';
    // final deliveryUserPhone = deliveryUserData?['phone'] as String?; // 如果需要外送員電話

    final items = List<Map<String, dynamic>>.from(receiptSubOrder['receipt_items'] ?? []);


    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('訂單 #${subOrderId.substring(0,8)}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('狀態: ${formatRestaurantReceiptStatus(subOrderStatus)}'),
                Text('本店金額: \$${subTotal.toStringAsFixed(2)}'),
                 if (originalCreatedAt != null) Text('下單時間: ${DateFormat('yyyy-MM-dd HH:mm').format(originalCreatedAt.toLocal())}'),
                Text('完成/歸檔於: ${DateFormat('yyyy-MM-dd HH:mm').format(archivedAt.toLocal())}'),
                const Divider(height: 20),
                Text('送餐地址: $deliveryAddress'),
                Text('顧客: $customerName'),
                if (customerPhone != null) Text('顧客電話: $customerPhone'),
                 if (customerNotes != null && customerNotes.isNotEmpty)
                  Text('顧客備註: $customerNotes', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                Text('外送員: $deliveryUserName'),
                 // if (deliveryUserPhone != null) Text('外送員電話: $deliveryUserPhone'),
                const Divider(height: 20),
                const Text('商品項目:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (items.isEmpty)
                  const Text(' - 無商品項目資訊', style: TextStyle(fontStyle: FontStyle.italic)),
                ...items.map((item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: (item['food_item_image_url'] as String?)?.isNotEmpty ?? false
                       ? Image.network(item['food_item_image_url'] as String, width: 40, height: 40, fit: BoxFit.cover,
                           errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),)
                       : const Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
                  title: Text('${item['food_item_name']} × ${item['quantity']}'),
                  trailing: Text('\$${(item['item_total_price'] as num).toStringAsFixed(2)}'),
                )).toList(),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('關閉'),
              onPressed: () { Navigator.of(context).pop(); },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('餐廳歷史訂單')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _receiptSubOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('目前沒有歷史訂單記錄。'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新整理'),
                        onPressed: _loadRestaurantReceipts,
                      )
                    ],
                  )
                )
              : RefreshIndicator(
                  onRefresh: _loadRestaurantReceipts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _receiptSubOrders.length,
                    itemBuilder: (context, index) {
                      final subReceipt = _receiptSubOrders[index];
                      final subOrderId = subReceipt['id'] as String;
                      final subTotal = (subReceipt['sub_total_amount'] as num).toDouble();
                      final archivedAt = DateTime.parse(subReceipt['archived_at'] as String);
                      final finalStatus = subReceipt['final_status'] as String?;

                      // 從嵌套查詢中獲取主訂單的顧客信息
                       final mainReceiptData = subReceipt['main_receipt'] as Map<String, dynamic>?;
                       final customerData = mainReceiptData?['users'] as Map<String, dynamic>?;
                       final customerName = customerData?['name'] as String? ?? '顧客';


                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        child: ListTile(
                          title: Text('訂單 #${subOrderId.substring(0, 8)} - ${formatRestaurantReceiptStatus(finalStatus)}'),
                          subtitle: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('歸檔於: ${DateFormat('yyyy-MM-dd HH:mm').format(archivedAt.toLocal())}'),
                               Text('金額: \$${subTotal.toStringAsFixed(2)}'),
                               Text('顧客: $customerName'),
                             ],
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                          onTap: () => _showReceiptSubOrderDetailDialog(subReceipt),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}