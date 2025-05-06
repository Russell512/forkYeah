// signup_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final supa = Supabase.instance.client;
  final _email = TextEditingController();
  final _pwd   = TextEditingController();
  final _name  = TextEditingController();
  String _role = 'customer';          // default 角色

  Future<void> _signup() async {
    try {
      // 1) 建 auth 帳號（metadata 放 role）
      final res = await supa.auth.signUp(
        email: _email.text.trim(),
        password: _pwd.text,
        data: { 'role': _role },
      );

      // 2) 再寫一筆 profile 進 public.users（FK 需要）
      await supa.from('users').upsert({
        'id'   : res.user!.id,
        'email': res.user!.email,
        'role' : _role,
        'name' : _name.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('註冊成功！請收信驗證')));
      Navigator.pop(context); // 返回上一頁
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('註冊失敗：$e')));
    }
  }

  Widget _field(TextEditingController c, String label,
          {bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('註冊 ForkYeah')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _field(_email, 'Email'),
              _field(_pwd, '密碼', obscure: true),
              _field(_name, '姓名'),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: '角色',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'customer',   child: Text('顧客')),
                    DropdownMenuItem(value: 'restaurant', child: Text('餐廳商家')),
                    DropdownMenuItem(value: 'carrier',    child: Text('外送員')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'customer'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signup,
                  child: const Text('建立帳號'),
                ),
              ),
            ],
          ),
        ),
      );
}
