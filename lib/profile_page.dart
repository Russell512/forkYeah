import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supa = Supabase.instance.client;
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = supa.auth.currentUser!.id;
    final data = await supa
        .from('users')
        .select('name, phone')
        .eq('id', uid)
        .single();
    setState(() {
      _name.text = (data['name'] ?? '') as String;
      _phone.text = (data['phone'] ?? '') as String;
    });
  }

  Future<void> _updateProfile() async {
    final uid = supa.auth.currentUser!.id;
    try {
      await supa.from('users').update({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
      }).eq('id', uid);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('更新成功 ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('更新失敗: $e')));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確定要刪除帳號？'),
        content: const Text('此操作無法復原。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('刪除', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final uid = supa.auth.currentUser!.id;
      // 1) 刪除 users 資料表中的 row
      await supa.from('users').delete().eq('id', uid);
      // 2) 登出
      await supa.auth.signOut();
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst); // 回首頁
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('帳號已刪除')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('個人檔案')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '姓名'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: '電話'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: _updateProfile, child: const Text('儲存變更')),
              TextButton(
                onPressed: _deleteAccount,
                child: const Text('刪除帳號',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }
}
