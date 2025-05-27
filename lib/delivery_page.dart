// lib/delivery_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // 用於日期格式化

// 可以從其他頁面共享或放到 utils
String formatOrderStatusForCarrier(String? status) {
  switch (status) {
    case 'ready_for_pickup': return '待取餐';
    // 外送員可能還需要看到其他狀態，但此頁面主要關注 'ready_for_pickup'
    default: return status ?? '未知';
  }
}
Color getOrderStatusColorForCarrier(String? status) {
  switch (status) {
    case 'ready_for_pickup': return Colors.lightGreen.shade400;
    default: return Colors.grey.shade400;
  }
}

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  bool _isAssigning = false; // 防止重複指派
  List<Map<String, dynamic>> _availableSubOrders = []; // 存儲 restaurant_orders
  final Set<String> _selectedSubOrderIds = {}; // 存儲選中的 restaurant_order 的 ID

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = supa.auth.currentUser;
    if (_currentUser == null) {
      _handleUnauthenticatedUser();
    } else {
      _loadAvailableSubOrders();
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


  Future<void> _loadAvailableSubOrders() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      // 查詢狀態為 'ready_for_pickup' 且 delivery_id 為 NULL 的 restaurant_orders
      // 同時獲取餐廳名稱和主訂單的送餐地址
      final response = await supa
          .from('restaurant_orders')
          .select('''
            id, 
            sub_total_amount, 
            created_at, 
            status,
            restaurant_id, 
            users!restaurant_orders_restaurant_id_fkey (name), 
            order_id,
            orders (delivery_address, notes, users!orders_user_id_fkey(name, phone))
          ''')
          .is_('delivery_id', null) // 確保還沒有被其他外送員接單
          .eq('status', 'ready_for_pickup')
          .order('created_at', ascending: true); // 優先顯示較早準備好的訂單

      if (mounted) {
        setState(() {
          _availableSubOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入待領取訂單失敗: $e')));
        setState(() => _isLoading = false);
      }
      debugPrint("Error loading available sub-orders: $e");
    }
  }

  Future<void> _assignSelectedOrders() async {
    if (_currentUser == null || _selectedSubOrderIds.isEmpty || _isAssigning) return;

    setState(() => _isAssigning = true);

    List<String> successfullyAssignedIds = [];
    List<String> failedToAssignIds = [];

    try {
      // 理想情況下，這應該是一個後端事務或 RPC 調用來確保原子性
      // 但為了分步，我們先在客戶端遍歷更新
      for (final subOrderId in _selectedSubOrderIds) {
        try {
          await supa
              .from('restaurant_orders')
              .update({
                'delivery_id': _currentUser!.id,
                'status': 'assigned_delivering'
              })
              .eq('id', subOrderId)
              .eq('status', 'ready_for_pickup') // 確保狀態仍是待取餐 (防止競爭條件)
              .is_('delivery_id', null); // 再次確認未被接單

          // 如果需要更新 users 表中外送員的 is_delivering 狀態，可以在這裡做
          // await supa.from('users').update({'is_delivering': true}).eq('id', _currentUser!.id);

          successfullyAssignedIds.add(subOrderId.substring(0,6));
        } catch (e) {
          failedToAssignIds.add(subOrderId.substring(0,6));
          debugPrint("Error assigning order $subOrderId: $e");
        }
      }

      if (mounted) {
        String message = '';
        if (successfullyAssignedIds.isNotEmpty) {
          message += '已成功指派訂單: ${successfullyAssignedIds.join(", ")}. ';
        }
        if (failedToAssignIds.isNotEmpty) {
          message += '部分訂單指派失敗: ${failedToAssignIds.join(", ")}. 可能已被其他外送員接取。';
        }
        if (message.isEmpty) {
          message = '沒有訂單被指派，可能已被接取。';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }

      _selectedSubOrderIds.clear(); // 清空已選中的
      await _loadAvailableSubOrders(); // 重新載入列表

    } catch (e) { // 這是遍歷循環之外的總體錯誤
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('指派過程中發生錯誤: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('待領取訂單')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableSubOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('目前沒有可領取的訂單。'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新整理'),
                        onPressed: _loadAvailableSubOrders,
                      )
                    ],
                  )
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAvailableSubOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _availableSubOrders.length,
                          itemBuilder: (context, i) {
                            final subOrder = _availableSubOrders[i];
                            final subOrderId = subOrder['id'] as String;
                            final subTotal = (subOrder['sub_total_amount'] as num).toDouble();
                            final createdAt = DateTime.parse(subOrder['created_at'] as String);

                            final restaurantData = subOrder['users'] as Map<String, dynamic>?; // 來自 users!restaurant_id
                            final restaurantName = restaurantData?['name'] as String? ?? '未知餐廳';

                            final mainOrderData = subOrder['orders'] as Map<String, dynamic>?;
                            final deliveryAddress = mainOrderData?['delivery_address'] as String? ?? '地址未提供';
                            final customerNotes = mainOrderData?['notes'] as String?;

                            final customerContactData = mainOrderData?['users'] as Map<String, dynamic>?; // 來自 orders (users!user_id)
                            final customerName = customerContactData?['name'] as String? ?? '顧客';
                            // final customerPhone = customerContactData?['phone'] as String?;


                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6.0),
                              child: CheckboxListTile(
                                title: Text('訂單 #${subOrderId.substring(0, 8)} (來自 $restaurantName)'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('送至: $deliveryAddress'),
                                    Text('顧客: $customerName'),
                                    // if (customerPhone != null) Text('電話: $customerPhone'),
                                    Text('金額: \$${subTotal.toStringAsFixed(2)}'),
                                    Text('準備時間: ${DateFormat('HH:mm').format(createdAt.toLocal())}'),
                                    if (customerNotes != null && customerNotes.isNotEmpty)
                                      Text('顧客備註: $customerNotes', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                                  ],
                                ),
                                value: _selectedSubOrderIds.contains(subOrderId),
                                onChanged: _isAssigning ? null : (bool? selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedSubOrderIds.add(subOrderId);
                                    } else {
                                      _selectedSubOrderIds.remove(subOrderId);
                                    }
                                  });
                                },
                                activeColor: Colors.green,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_availableSubOrders.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isAssigning
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_circle_outline),
                            label: Text(_isAssigning ? '指派中...' : '接取已選訂單 (${_selectedSubOrderIds.length})'),
                            onPressed: (_selectedSubOrderIds.isEmpty || _isAssigning) ? null : _assignSelectedOrders,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )
                  ],
                ),
    );
  }
}