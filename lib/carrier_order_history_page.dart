// lib/carrier_order_history_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// 輔助函數 (可以共享或從 utils 文件引入)
String formatCarrierReceiptStatus(String? status) {
  // 外送員看到的歷史狀態可能與餐廳或顧客略有不同，但很多是重疊的
  switch (status) {
    case 'completed': return '已完成配送';
    case 'delivered': return '已送達'; // 通常歸檔後都應是 'completed'
    case 'cancelled_by_customer': return '顧客取消此單';
    case 'cancelled_by_restaurant': return '店家取消此單';
    default: return status ?? '未知狀態';
  }
}
Color getCarrierReceiptStatusColor(String? status) {
  switch (status) {
    case 'completed':
    case 'delivered':
      return Colors.green.shade400;
    case 'cancelled_by_customer':
    case 'cancelled_by_restaurant':
      return Colors.orange.shade700; // 或其他顏色表示非正常完成
    default:
      return Colors.grey.shade400;
  }
}

class CarrierOrderHistoryPage extends StatefulWidget {
  const CarrierOrderHistoryPage({super.key});

  @override
  State<CarrierOrderHistoryPage> createState() => _CarrierOrderHistoryPageState();
}

class _CarrierOrderHistoryPageState extends State<CarrierOrderHistoryPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _carrierReceipts = []; // 存儲已歸檔的、由該外送員配送的子訂單
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = supa.auth.currentUser;
    if (_currentUser == null) {
      _handleUnauthenticatedUser();
    } else {
      _loadCarrierReceipts();
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

  Future<void> _loadCarrierReceipts() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      // 查詢 delivery_id 為當前外送員的 receipt_restaurant_orders
      // !!! 請務必替換下面的外鍵提示名稱為你的實際名稱 !!!
      const String restaurantUserFKey = 'receipt_restaurant_orders_restaurant_id_fkey'; // receipt_restaurant_orders.restaurant_id -> users.id
      const String mainReceiptFKey = 'receipt_restaurant_orders_receipt_id_fkey';   // receipt_restaurant_orders.receipt_id -> receipts.id
      const String customerUserFKey = 'receipts_user_id_fkey';      // receipts.user_id -> users.id

      debugPrint("CarrierOrderHistoryPage: Loading receipts for carrier ${_currentUser!.id}");

      final response = await supa
          .from('receipt_restaurant_orders') // 主查詢表是 receipt_restaurant_orders
          .select('''
            id, 
            restaurant_id, 
            delivery_id, 
            final_status, 
            sub_total_amount, 
            original_created_at, 
            archived_at,
            restaurant_info:users!$restaurantUserFKey(name, phone, address, county, district), 
            main_receipt_info:receipts!$mainReceiptFKey ( 
               user_id, 
               delivery_address, 
               notes, 
               customer_info:users!$customerUserFKey(name, phone) 
            ),
            receipt_items ( 
              food_item_name, 
              food_item_image_url, 
              quantity, 
              unit_price, 
              item_total_price 
            )
          ''')
          .eq('delivery_id', _currentUser!.id) // 只查詢由當前外送員配送的
          // 可以篩選最終狀態，例如只看 'delivered' 或 'completed'
          // .in_('final_status', ['delivered', 'completed'])
          .order('archived_at', ascending: false);

      if (mounted) {
        setState(() {
          _carrierReceipts = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入外送記錄失敗: $e')));
        setState(() => _isLoading = false);
      }
      debugPrint("Error loading carrier receipts: $e");
      debugPrint("Stack trace for loading carrier receipts: $stackTrace");
    }
  }

  void _showCarrierReceiptDetailDialog(Map<String, dynamic> subOrderReceipt) {
    final subOrderId = subOrderReceipt['id'] as String;
    final finalStatus = subOrderReceipt['final_status'] as String?;
    final subTotal = (subOrderReceipt['sub_total_amount'] as num).toDouble();
    final archivedAt = DateTime.parse(subOrderReceipt['archived_at'] as String);

    final restaurantData = subOrderReceipt['restaurant_info'] as Map<String, dynamic>?;
    final restaurantName = restaurantData?['name'] as String? ?? '未知餐廳';
    final restaurantAddress = "${restaurantData?['county'] ?? ''}${restaurantData?['district'] ?? ''}${restaurantData?['address'] ?? ''}";


    final mainReceiptData = subOrderReceipt['main_receipt_info'] as Map<String, dynamic>?;
    final deliveryAddress = mainReceiptData?['delivery_address'] as String? ?? '地址未提供';
    final customerData = mainReceiptData?['customer_info'] as Map<String, dynamic>?;
    final customerName = customerData?['name'] as String? ?? '顧客';
    final customerPhone = customerData?['phone'] as String?;

    final items = List<Map<String, dynamic>>.from(subOrderReceipt['receipt_items'] ?? []);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('外送詳情 #${subOrderId.substring(0,8)}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('狀態: ${formatCarrierReceiptStatus(finalStatus)}'),
                Text('配送費/小費 (此單): \$${subTotal.toStringAsFixed(2)}'), // 這裡的 subTotal 是餐廳的子訂單金額，外送費可能需要單獨計算或記錄
                Text('完成時間: ${DateFormat('yyyy-MM-dd HH:mm').format(archivedAt.toLocal())}'),
                const Divider(height: 20),
                Text('取餐地點: $restaurantName', style: TextStyle(fontWeight: FontWeight.bold)),
                if(restaurantAddress.isNotEmpty) Text(restaurantAddress),
                const SizedBox(height: 10),
                Text('送達地點: $deliveryAddress', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('顧客: $customerName'),
                if (customerPhone != null) Text('顧客電話: $customerPhone'),
                const Divider(height: 20),
                const Text('配送商品:', style: TextStyle(fontWeight: FontWeight.bold)),
                 if (items.isEmpty)
                  const Text(' - 無商品項目資訊', style: TextStyle(fontStyle: FontStyle.italic)),
                ...items.map((item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: (item['food_item_image_url'] as String?)?.isNotEmpty ?? false
                       ? Image.network(item['food_item_image_url'] as String, width: 30, height: 30, fit: BoxFit.cover,
                           errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, size: 30, color: Colors.grey),)
                       : const Icon(Icons.fastfood, size: 30, color: Colors.grey),
                  title: Text('${item['food_item_name']} × ${item['quantity']}'),
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
      appBar: AppBar(title: const Text('我的外送記錄')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _carrierReceipts.isEmpty
              ? Center(
                  child: Column( /* ... (無記錄時的 UI) ... */)
                )
              : RefreshIndicator(
                  onRefresh: _loadCarrierReceipts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _carrierReceipts.length,
                    itemBuilder: (context, index) {
                      final receipt = _carrierReceipts[index];
                      final subOrderId = receipt['id'] as String;
                      final archivedAt = DateTime.parse(receipt['archived_at'] as String);
                      final finalStatus = receipt['final_status'] as String?;

                      final restaurantData = receipt['restaurant_info'] as Map<String, dynamic>?;
                      final restaurantName = restaurantData?['name'] as String? ?? '未知餐廳';

                      final mainReceiptData = receipt['main_receipt_info'] as Map<String, dynamic>?;
                      final deliveryAddress = mainReceiptData?['delivery_address'] as String? ?? '地址未提供';


                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        child: ListTile(
                          leading: Icon(Icons.delivery_dining_outlined, color: getCarrierReceiptStatusColor(finalStatus)),
                          title: Text('訂單 #${subOrderId.substring(0,8)} - ${formatCarrierReceiptStatus(finalStatus)}'),
                          subtitle: Text('取餐: $restaurantName\n送至: $deliveryAddress\n完成於: ${DateFormat('yy-MM-dd HH:mm').format(archivedAt.toLocal())}'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _showCarrierReceiptDetailDialog(receipt),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}