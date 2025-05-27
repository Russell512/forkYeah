// lib/my_coupons_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MyCouponsPage extends StatefulWidget {
  const MyCouponsPage({super.key});

  @override
  State<MyCouponsPage> createState() => _MyCouponsPageState();
}

class _MyCouponsPageState extends State<MyCouponsPage> {
  final supa = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _userCouponsDetails = [];
  User? _currentUser;
  bool _isProcessingCoupon = false;

  @override
  void initState() {
    super.initState();
    _currentUser = supa.auth.currentUser;
    if (_currentUser == null) {
      _handleUnauthenticatedUser();
    } else {
      _loadUserCoupons();
    }
  }

  void _handleUnauthenticatedUser() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入以查看您的優惠券')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserCoupons() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      // !!! 確保 'user_coupons_coupon_id_fkey' 是你 user_coupons.coupon_id -> coupons.id 的實際外鍵名 !!!
      const String couponDetailsForeignKeyHint = 'coupons!user_coupons_coupon_id_fkey'; // 使用你確認過的實際外鍵名
      debugPrint("MyCouponsPage: Loading coupons for user ${_currentUser!.id}");
      debugPrint("Using couponDetailsForeignKeyHint: $couponDetailsForeignKeyHint");

      final response = await supa
          .from('user_coupons')
          .select('''
            id, 
            coupon_id, 
            claimed_at, 
            redeemed,
            coupon_details:$couponDetailsForeignKeyHint (
              label, 
              description, 
              expires_at, 
              quota, 
              coupon_type
            ) 
          ''')
          .eq('user_id', _currentUser!.id)
          // .eq('redeemed', false) // 可以先註釋掉，方便測試所有券
          .order('claimed_at', ascending: false);

      if (mounted) {
        setState(() {
          _userCouponsDetails = List<Map<String, dynamic>>.from(
            response.where((uc) => uc['coupon_details'] != null)
          );
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入優惠券失敗: $e')));
      }
      debugPrint("Error loading user coupons: $e");
      debugPrint("Stack trace for loading user coupons: $stackTrace");
    } finally {
      if(mounted){
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatExpiryDate(String? expiresAtStr) {
    if (expiresAtStr == null || expiresAtStr.isEmpty) {
      return '永久有效';
    }
    try {
      final expiryDate = DateTime.parse(expiresAtStr);
      if (expiryDate.isBefore(DateTime.now())) {
        return '已過期 (${DateFormat('yyyy-MM-dd').format(expiryDate)})';
      }
      return '有效至: ${DateFormat('yyyy-MM-dd').format(expiryDate)}';
    } catch (e) {
      return '日期無效';
    }
  }

  Future<void> _useCoupon(Map<String, dynamic> userCouponData) async {
    if (_currentUser == null || _isProcessingCoupon) return;
    setState(() => _isProcessingCoupon = true);

    final String userCouponId = userCouponData['id'] as String;
    final Map<String, dynamic> couponDetails = userCouponData['coupon_details'] as Map<String, dynamic>;
    final String? couponType = couponDetails['coupon_type'] as String?;

    bool shouldMarkAsRedeemed = true; // 預設都要標記為已使用

    // 根據 coupon_type 判斷是否應該標記為已使用
    if (couponType == 'permanent_free_meal') {
      shouldMarkAsRedeemed = false;
    }
    // 對於 'free_meal', 'discount_amount', 和其他 (你說的 'nothing')，都應該被標記
    // 所以上面的預設值 true 已經包含了這些情況。

    try {
      if (shouldMarkAsRedeemed) {
        await supa
            .from('user_coupons')
            .update({'redeemed': true})
            .eq('id', userCouponId)
            .eq('user_id', _currentUser!.id);
        debugPrint("User coupon $userCouponId (type: $couponType) marked as redeemed.");
      } else {
        debugPrint("Coupon $userCouponId (type: $couponType) used, but not marking as redeemed (e.g., permanent).");
      }

      if (mounted) {
        // 返回 couponDetails 給 CartPage，以便 CartPage 知道是哪張券以及如何應用
        // couponDetails 應該包含 label, description, coupon_type，以及可能的 discount_value (如果有的話)
        Navigator.pop(context, couponDetails);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('使用優惠券時發生錯誤: $e')));
      }
      debugPrint("Error processing coupon $userCouponId: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessingCoupon = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('選擇您的優惠券')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userCouponsDetails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('您目前沒有可用的優惠券。'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新整理'),
                        onPressed: _loadUserCoupons,
                      )
                    ],
                  )
                )
              : RefreshIndicator(
                  onRefresh: _loadUserCoupons,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: _userCouponsDetails.length,
                    itemBuilder: (context, index) {
                      final userCouponItem = _userCouponsDetails[index];
                      final couponDetails = userCouponItem['coupon_details'] as Map<String, dynamic>;
                      final bool isRedeemed = userCouponItem['redeemed'] as bool? ?? false;
                      final String claimedAtStr = userCouponItem['claimed_at'] as String;
                      final DateTime claimedAt = DateTime.parse(claimedAtStr);

                      final String label = couponDetails['label'] as String? ?? '未知優惠券';
                      final String description = couponDetails['description'] as String? ?? '無描述';
                      final String? expiresAt = couponDetails['expires_at'] as String?;
                      final String? couponType = couponDetails['coupon_type'] as String?; // 用於判斷是否永久

                      bool isExpired = false;
                      if (expiresAt != null) {
                        try {
                            if (DateTime.parse(expiresAt).isBefore(DateTime.now())) {
                                isExpired = true;
                            }
                        } catch(_){}
                      }

                      // 只有未過期且未使用的優惠券才能被選擇使用
                      // 如果是 'permanent_free_meal'，即使它在 user_coupons 中 redeemed=false，它也總是可用的
                      final bool canUseButtonBeEnabled;
                      if (couponType == 'permanent_free_meal') {
                        canUseButtonBeEnabled = !isExpired; // 永久券只要沒過期就能一直用
                      } else {
                        canUseButtonBeEnabled = !isRedeemed && !isExpired;
                      }

                      return Card(
                        elevation: canUseButtonBeEnabled ? 3 : 1,
                        margin: const EdgeInsets.only(bottom: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: !canUseButtonBeEnabled && couponType != 'permanent_free_meal' // 永久券即使不能再“使用”（因為它不標記redeemed），也不顯示灰色邊框
                              ? BorderSide(color: Colors.grey.shade400, width: 1)
                              : BorderSide.none,
                        ),
                        color: !canUseButtonBeEnabled && couponType != 'permanent_free_meal' ? Colors.grey.shade200 : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          leading: Icon(
                            isRedeemed ? Icons.check_circle_outline_rounded : (isExpired ? Icons.timer_off_outlined : Icons.local_offer_outlined),
                            color: isRedeemed ? Colors.green : (isExpired ? Colors.orange.shade700 : Theme.of(context).primaryColor),
                            size: 36,
                          ),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (!canUseButtonBeEnabled && couponType != 'permanent_free_meal') ? Colors.grey.shade600 : Colors.black87,
                              decoration: (isRedeemed && couponType != 'permanent_free_meal') ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(description, style: TextStyle(color: (!canUseButtonBeEnabled && couponType != 'permanent_free_meal') ? Colors.grey.shade600 : Colors.black54)),
                              const SizedBox(height: 4),
                              Text(
                                _formatExpiryDate(expiresAt),
                                style: TextStyle(fontSize: 12, color: isExpired ? Colors.red.shade700 : Colors.grey.shade700),
                              ),
                              Text(
                                '領取於: ${DateFormat('yyyy-MM-dd HH:mm').format(claimedAt.toLocal())}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          trailing: canUseButtonBeEnabled
                              ? ElevatedButton(
                                  onPressed: _isProcessingCoupon ? null : () => _useCoupon(userCouponItem),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 13)
                                  ),
                                  child: _isProcessingCoupon
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('使用此券', style: TextStyle(color: Colors.white)),
                                )
                              : (isRedeemed && couponType != 'permanent_free_meal' // 永久券不顯示已使用
                                  ? const Chip(label: Text('已使用'), backgroundColor: Colors.grey)
                                  : (isExpired
                                      ? const Chip(label: Text('已過期'), backgroundColor: Colors.orange)
                                      : (couponType == 'permanent_free_meal' // 如果是永久券但未過期，仍然顯示可使用按鈕
                                          ? ElevatedButton(
                                              onPressed: _isProcessingCoupon ? null : () => _useCoupon(userCouponItem),
                                              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), textStyle: const TextStyle(fontSize: 13)),
                                              child: _isProcessingCoupon ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('使用此券', style: TextStyle(color: Colors.white)),
                                            )
                                          : const SizedBox.shrink() // 其他情況（例如，邏輯不應到達這裡）
                                        )
                                    )
                                ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}