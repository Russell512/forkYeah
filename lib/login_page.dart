import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final supa = Supabase.instance.client;

  Future<void> login() async {
    try {
      await supa.auth.signInWithPassword(
        email: _email.text,
        password: _password.text,
      );
      if (mounted) Navigator.pop(context); // 回首頁
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('登入失敗: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('登入')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _password, decoration: const InputDecoration(labelText: '密碼'), obscureText: true),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: login, child: const Text('登入')),
            ],
          ),
        ),
      );
}
