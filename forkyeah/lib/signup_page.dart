import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  String role = 'customer';                        // 預設角色
  final _email           = TextEditingController();
  final _password        = TextEditingController();
  final _name            = TextEditingController();
  final _phone           = TextEditingController();
  final _address         = TextEditingController();   // customer
  final _county          = TextEditingController();   // restaurant
  final _district        = TextEditingController();
  final _serviceDistrict = TextEditingController();   // carrier
  final _serviceTime     = TextEditingController();

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    for (final c in [
      _email,_password,_name,_phone,
      _address,_county,_district,_serviceDistrict,_serviceTime
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> signup() async {
    try {
      // 1) 建立 Auth 帳號
      final auth = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );

      final uid = auth.user?.id;
      if (uid == null) throw '無法取得使用者 ID';

      // 2) 寫入自訂 users 表
      await supabase.from('users').insert({
        'id'              : uid,
        'email'           : _email.text.trim(),
        'role'            : role,
        'name'            : _name.text.trim(),
        'phone'           : _phone.text.trim(),
        'address'         : role == 'customer'   ? _address.text.trim()         : null,
        'county'          : role == 'restaurant' ? _county.text.trim()          : null,
        'district'        : role == 'restaurant' ? _district.text.trim()        : null,
        'service_district': role == 'carrier'    ? _serviceDistrict.text.trim() : null,
        'service_time'    : role == 'carrier'    ? _serviceTime.text.trim()     : null,
      });

      if (mounted) {
        Navigator.pop(context); // 回首頁
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('註冊成功 ✅')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('註冊失敗: $e')),
      );
    }
  }

  //--------------------------------------------------------------------
  // 動態表單
  //--------------------------------------------------------------------
  Widget _buildFormFields() {
    switch (role) {
      case 'customer':
        return Column(
          children: [
            _field(_name,  '姓名'),
            _field(_phone, '電話'),
            _field(_address, '地址'),
          ],
        );

      case 'restaurant':
        return Column(
          children: [
            _field(_name,    '餐廳名稱'),
            _field(_county,  '縣市'),
            _field(_district,'區域'),
          ],
        );

      case 'carrier':
        return Column(
          children: [
            _field(_name,          '姓名'),
            _field(_phone,         '電話'),
            _field(_serviceDistrict,'服務地區'),
            _field(_serviceTime,    '服務時間'),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  //--------------------------------------------------------------------
  // 共用輸入框
  //--------------------------------------------------------------------
  Widget _field(TextEditingController c, String label,
      {bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  //--------------------------------------------------------------------
  // 畫面
  //--------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 角色選擇
            DropdownButton<String>(
              value: role,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'customer',   child: Text('顧客')),
                DropdownMenuItem(value: 'restaurant', child: Text('餐廳')),
                DropdownMenuItem(value: 'carrier',    child: Text('外送員')),
              ],
              onChanged: (v) => setState(() => role = v!),
            ),
            const SizedBox(height: 16),

            // Email & Password
            _field(_email,    'Email'),
            _field(_password, '密碼', obscure: true),

            const SizedBox(height: 16),
            _buildFormFields(),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: signup,
              child: const Text('註冊'),
            ),
          ],
        ),
      ),
    );
  }
}
