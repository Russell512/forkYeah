import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';

class CouponWheelPage extends StatefulWidget {
  const CouponWheelPage({super.key});
  @override
  State<CouponWheelPage> createState() => _CouponWheelPageState();
}

class _CouponWheelPageState extends State<CouponWheelPage> {
  final supa = Supabase.instance.client;
  final Random _rand = Random();
  final StreamController<int> _selected = StreamController<int>();

  List<Map<String, dynamic>> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  @override
  void dispose() {
    _selected.close();
    super.dispose();
  }

  Future<void> _loadCoupons() async {
    try {
      final data = await supa.from('coupons').select('id, label');
      setState(() {
        _coupons = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('載入優惠券失敗: $e')));
      }
    }
  }

  Future<void> _recordCoupon(String couponId) async {
    final uid = supa.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await supa.from('user_coupons').insert({
        'user_id': uid,
        'coupon_id': couponId,
      });
    } catch (e) {
      // 插入失敗不影響 UI，僅提示即可
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('儲存優惠券失敗: $e')));
      }
    }
  }

  void _spin() {
    if (_coupons.isEmpty) return;
    final index = _rand.nextInt(_coupons.length);
    _selected.add(index);

    // 等輪盤停下來 (~4s) 再顯示結果 & 寫 DB
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final coupon = _coupons[index];

      _recordCoupon(coupon['id'] as String);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('恭喜！'),
          content: Text('你抽中了：${coupon['label']} 🎉'),
          actions: [
            TextButton(
              child: const Text('開心收下'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final yellow = const Color(0xfffecb2f);
    final blue = const Color(0xff007aff);
    final bg = const Color(0xfffafdfc);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _coupons.isEmpty
                ? const Center(child: Text('目前沒有可抽的優惠券'))
                : Column(
                    children: [
                      // ===== 霓虹 ForkYeah 標題 =====
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Center(
                          child: Text(
                            'ForkYeah',
                            style: GoogleFonts.pacifico(
                              fontSize: 38,
                              color: yellow,
                              shadows: const [
                                Shadow(blurRadius: 10, color: Colors.yellow),
                                Shadow(blurRadius: 20, color: Colors.yellow),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          // 置中輪盤
                          child: SizedBox(
                            height: 320,
                            width: 320,
                            child: FortuneWheel(
                              selected: _selected.stream,
                              indicators: [
                                FortuneIndicator(
                                  alignment: Alignment.topCenter,
                                  child: TriangleIndicator(
                                    color: blue,
                                  ),
                                ),
                              ],
                              items: [
                                for (final c in _coupons)
                                  FortuneItem(
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Text(
                                        c['label'] as String,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    style: FortuneItemStyle(
                                      color: _coupons.indexOf(c) % 2 == 0
                                          ? yellow
                                          : blue,
                                      borderColor: bg,
                                      borderWidth: 2,
                                    ),
                                  ),
                              ],
                              physics: CircularPanPhysics(
                                duration: const Duration(seconds: 4),
                                curve: Curves.decelerate,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.local_activity),
                        label: const Text('開始抽券'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 36, vertical: 16),
                          textStyle: const TextStyle(fontSize: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32)),
                          elevation: 6,
                          shadowColor: blue.withOpacity(0.6),
                        ),
                        onPressed: _spin,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
      ),
    );
  }
}
