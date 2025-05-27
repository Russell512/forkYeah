// lib/coupon_wheel_page.dart
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
  bool _isSpinning = false;

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
    setState(() => _loading = true); // 確保開始載入時設置
    try {
      final data = await supa.from('coupons').select('id, label');
      if (!mounted) return;
      setState(() {
        _coupons = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('載入優惠券失敗: $e')));
      }
    } finally { // <--- 確保在 finally 中設置 _loading = false
        if (mounted) {
            setState(() => _loading = false);
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('儲存優惠券失敗: $e')));
      }
    }
  }

  void _spin() {
    if (_coupons.isEmpty || _isSpinning) return;
    setState(() => _isSpinning = true);

    final index = _rand.nextInt(_coupons.length);
    _selected.add(index);

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) { // 如果 widget 在延遲期間被 dispose，則提前返回
        setState(() => _isSpinning = false);
        return;
      }
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
      setState(() => _isSpinning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final yellow = const Color(0xfffecb2f);
    final blue = const Color(0xff007aff);
    final bg = const Color(0xfffafdfc);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('折價券轉盤'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: blue), // 確保返回按鈕是可見的顏色
        titleTextStyle: GoogleFonts.pacifico(fontSize: 24, color: yellow),
        actions: [
          IconButton(
            icon: Icon(Icons.confirmation_num_outlined, color: blue),
            tooltip: '我的優惠券',
            onPressed: () {
              Navigator.pushNamed(context, '/my_coupons');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _coupons.isEmpty
                ? Center(
                    child: Column( // 如果沒有優惠券，也提供刷新按鈕
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Text('目前沒有可抽的優惠券'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('重新整理'),
                                onPressed: _loadCoupons,
                            )
                        ],
                    )
                  )
                : Column(
                    children: [
                      // ===== 霓虹 ForkYeah 標題 =====
                      Padding( // <--- 修正 Padding
                        padding: const EdgeInsets.only(top: 24.0), // <--- 添加了 padding 參數
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
                          child: SizedBox(
                            height: 320,
                            width: 320,
                            child: FortuneWheel(
                              selected: _selected.stream,
                              animateFirst: false, // 避免初始動畫，除非你想要
                              indicators: [
                                FortuneIndicator(
                                  alignment: Alignment.topCenter,
                                  child: TriangleIndicator(color: blue),
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
                                      color: _coupons.indexOf(c) % 2 == 0 ? yellow : blue,
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
                      ElevatedButton.icon( // <--- 修正 ElevatedButton.icon
                        icon: const Icon(Icons.local_activity),
                        label: const Text('開始抽券'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                          textStyle: const TextStyle(fontSize: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                          elevation: 6,
                          shadowColor: blue.withOpacity(0.6),
                        ),
                        onPressed: _isSpinning ? null : _spin, // <--- 添加了 onPressed 參數
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
      ),
    );
  }
}