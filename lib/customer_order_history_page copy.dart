// lib/customer_order_history_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// 輔助函數 (建議放到共享 utils 文件)
String formatReceiptStatus(String? status) {
  switch (status) {
    case 'completed': return '已完成';
    case 'delivered': return '已送達';
    case 'cancelled_by_customer': return '已取消 (由您)';
    case 'cancelled_by_restaurant': return '已取消 (店家)';
    default: return status ?? '未知狀態';
  }
}
Color getReceiptStatusColor(String? status) {
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

class CustomerOrderHistoryPage extends StatefulWidget {
  const CustomerOrderHistoryPage({super.key});

  @override
  State<CustomerOrderHistoryPage> createState() => _CustomerOrderHistoryPageState();
}

class _CustomerOrderHistoryPageState extends State<CustomerOrderHistoryPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _receipts = [];
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    debugPrint("CustomerOrderHistoryPage: initState CALLED");
    _currentUser = supa.auth.currentUser;
    if (_currentUser == null) {
      debugPrint("CustomerOrderHistoryPage: User is NULL in initState. Calling _handleUnauthenticatedUser.");
      _handleUnauthenticatedUser();
    } else {
      debugPrint("CustomerOrderHistoryPage: User FOUND in initState. User ID: ${_currentUser!.id}. Calling _loadReceipts.");
      _loadReceipts();
    }
  }

   void _handleUnauthenticatedUser() {
      debugPrint("CustomerOrderHistoryPage: _handleUnauthenticatedUser CALLED.");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint("CustomerOrderHistoryPage: _handleUnauthenticatedUser - Popping to first route.");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入以查看歷史訂單')));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      if (mounted) {
        setState(() => _isLoading = false); // 確保 isLoading 被更新
      }
  }

  Future<void> _loadReceipts() async {
    if (_currentUser == null) {
      debugPrint("CustomerOrderHistoryPage: _loadReceipts - currentUser is NULL, returning.");
      if(mounted) setState(() => _isLoading = false); // 確保 isLoading 被更新
      return;
    }
    debugPrint("CustomerOrderHistoryPage: _loadReceipts - Setting isLoading to true.");
    setState(() => _isLoading = true);

    try {
      // !!! 重要: 請務必將下面的 'YOUR_ACTUAL_FOREIGN_KEY_NAME' 替換為你
      // receipt_restaurant_orders.restaurant_id 指向 users.id 的【實際外鍵約束名稱】!!!
      // 例如，如果你的外鍵名是 'receipt_restaurant_orders_restaurant_id_fkey'，就用它。
      const String restaurantUserForeignKeyHint = 'users!receipt_restaurant_orders_restaurant_id_fkey';
      debugPrint("CustomerOrderHistoryPage: _loadReceipts - Using FK hint: $restaurantUserForeignKeyHint");


      final response = await supa
          .from('receipts')
          .select('''
            id, 
            total_amount, 
            original_created_at, 
            completed_at, 
            final_status,
            delivery_address,
            notes,
            receipt_restaurant_orders ( 
              id, 
              restaurant_id, 
              final_status, 
              sub_total_amount, 
              $restaurantUserForeignKeyHint (name), 
              receipt_items ( 
                food_item_name, 
                food_item_image_url, 
                quantity, 
                unit_price, 
                item_total_price 
              )
            )
          ''')
          .eq('user_id', _currentUser!.id)
          .order('completed_at', ascending: false);

      debugPrint("CustomerOrderHistoryPage: _loadReceipts - Query successful, ${response.length} receipts found.");
      if (mounted) {
        setState(() {
          _receipts = List<Map<String, dynamic>>.from(response);
          // _isLoading = false; // 這行移到 finally
        });
      }
    } catch (e, stackTrace) { // <--- 添加 stackTrace
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入歷史訂單失敗: $e')));
        // setState(() => _isLoading = false); // 這行移到 finally
      }
      debugPrint("CustomerOrderHistoryPage: _loadReceipts - ERROR: $e");
      debugPrint("CustomerOrderHistoryPage: _loadReceipts - STACK TRACE: $stackTrace"); // <--- 打印堆棧跟踪
    } finally {
      if(mounted){
        debugPrint("CustomerOrderHistoryPage: _loadReceipts - Setting isLoading to false in finally block.");
        setState(() => _isLoading = false);
      }
    }
  }

  void _showReceiptDetailDialog(Map<String, dynamic> receipt) {
    // ... (此方法保持不變，但要注意從嵌套查詢中提取 restaurantData 的鍵名) ...
    final receiptId = receipt['id'] as String;
    final totalAmount = (receipt['total_amount'] as num).toDouble();
    final originalCreatedAt = receipt['original_created_at'] != null ? DateTime.parse(receipt['original_created_at'] as String) : null;
    final completedAt = DateTime.parse(receipt['completed_at'] as String);
    final finalStatus = receipt['final_status'] as String?;
    final restaurantOrders = List<Map<String, dynamic>>.from(receipt['receipt_restaurant_orders'] ?? []);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('歷史訂單 #${receiptId.substring(0,8)}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('總金額: \$${totalAmount.toStringAsFixed(2)}'),
                if (originalCreatedAt != null) Text('原下單時間: ${DateFormat('yyyy-MM-dd HH:mm').format(originalCreatedAt.toLocal())}'),
                Text('完成時間: ${DateFormat('yyyy-MM-dd HH:mm').format(completedAt.toLocal())}'),
                Text('最終狀態: ${formatReceiptStatus(finalStatus)}'),
                const Divider(height: 20),
                if (restaurantOrders.isNotEmpty)
                  const Text('餐廳訂單詳情:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...restaurantOrders.map((subOrder) {
                  // !!! 重要: 這裡的 'users' 鍵名取決於你在 select 語句中使用的外鍵提示或別名 !!!
                  // 如果你使用了像 restaurant_info:users!fk_name(name) 這樣的別名，這裡應該是 subOrder['restaurant_info']
                  final restaurantData = subOrder['users'] as Map<String, dynamic>?;
                  final restaurantName = restaurantData?['name'] as String? ?? '未知餐廳';
                  final subOrderStatus = subOrder['final_status'] as String?;
                  final items = List<Map<String, dynamic>>.from(subOrder['receipt_items'] ?? []);
                  return ExpansionTile(
                    title: Text('$restaurantName - 狀態: ${formatReceiptStatus(subOrderStatus)}'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    childrenPadding: const EdgeInsets.only(left: 16.0),
                    children: items.map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item['food_item_name']} × ${item['quantity']}'),
                      trailing: Text('\$${(item['item_total_price'] as num).toStringAsFixed(2)}'),
                    )).toList(),
                  );
                }),
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
    debugPrint("CustomerOrderHistoryPage: build CALLED, isLoading: $_isLoading, receipts count: ${_receipts.length}");
    return Scaffold(
      appBar: AppBar(title: const Text('歷史訂單')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _receipts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('沒有歷史訂單記錄。'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新整理'),
                        onPressed: _loadReceipts,
                      )
                    ],
                  )
                )
              : RefreshIndicator(
                  onRefresh: _loadReceipts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _receipts.length,
                    itemBuilder: (context, index) {
                      final receipt = _receipts[index];
                      final receiptId = receipt['id'] as String;
                      final totalAmount = (receipt['total_amount'] as num).toDouble();
                      final completedAt = DateTime.parse(receipt['completed_at'] as String);
                      final finalStatus = receipt['final_status'] as String?;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        child: ListTile(
                          title: Text('訂單 #${receiptId.substring(0, 8)} - ${formatReceiptStatus(finalStatus)}'),
                          subtitle: Text('完成於: ${DateFormat('yyyy-MM-dd HH:mm').format(completedAt.toLocal())}  總額: \$${totalAmount.toStringAsFixed(2)}'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                          onTap: () => _showReceiptDetailDialog(receipt),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}