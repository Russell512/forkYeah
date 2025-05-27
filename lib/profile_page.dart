// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supa = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>(); // 用於表單驗證

  // 現有欄位
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // 新增的地址相關欄位
  final _addressController = TextEditingController();
  final _countyController = TextEditingController();
  final _districtController = TextEditingController();

  // 特定角色欄位
  final _serviceDistrictController = TextEditingController(); // 外送員
  final _serviceTimeController = TextEditingController();   // 餐廳

  String? _userId;
  String _userRole = ''; // 用於判斷顯示哪些欄位
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = supa.auth.currentUser;
      if (user == null) {
        _handleUnauthenticatedUser();
        return;
      }
      _userId = user.id;

      // 從 users 表獲取包括 role 和其他所有需要編輯的欄位
      final profileData = await supa
          .from('users')
          .select('name, phone, address, county, district, role, service_district, service_time')
          .eq('id', _userId!)
          .maybeSingle();

      if (mounted && profileData != null) {
        _nameController.text = profileData['name'] ?? '';
        _phoneController.text = profileData['phone'] ?? '';
        _addressController.text = profileData['address'] ?? '';
        _countyController.text = profileData['county'] ?? '';
        _districtController.text = profileData['district'] ?? '';
        _userRole = profileData['role'] ?? ''; // 從 users 表獲取 role

        if (_userRole == 'restaurant') {
          _serviceTimeController.text = profileData['service_time'] ?? '';
        } else if (_userRole == 'carrier') {
          _serviceDistrictController.text = profileData['service_district'] ?? '';
        }
      } else if (mounted && profileData == null) {
        // 如果 users 表中還沒有該用戶的記錄
        // 我們可以嘗試從 auth.userMetadata 獲取 role (如果註冊時有存)
        _userRole = user.userMetadata?['role'] as String? ?? 'customer'; // 預設為 customer
        // 頁面會顯示空的輸入框，讓用戶首次填寫
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('歡迎！請填寫您的個人資料。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入個人資料失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleUnauthenticatedUser() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate() || _userId == null) {
      return;
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'county': _countyController.text.trim(),
        'district': _districtController.text.trim(),
      };

      if (_userRole == 'restaurant') {
        updates['service_time'] = _serviceTimeController.text.trim();
      } else if (_userRole == 'carrier') {
        updates['service_district'] = _serviceDistrictController.text.trim();
      }

      // 檢查 users 表中是否已有該用戶的記錄
      final existingUser = await supa.from('users').select('id').eq('id', _userId!).maybeSingle();

      if (existingUser == null) {
        // 如果 users 表中沒有記錄，則執行 insert
        updates['id'] = _userId!;
        updates['email'] = supa.auth.currentUser!.email!;
        updates['role'] = _userRole; // _userRole 應該已經在 _loadProfile 中被賦值

        await supa.from('users').insert(updates);
        debugPrint("Profile inserted for user: $_userId");
      } else {
        // 如果已有記錄，則執行 update
        await supa.from('users').update(updates).eq('id', _userId!);
        debugPrint("Profile updated for user: $_userId");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('個人資料已更新 ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新個人資料失敗: $e')));
      }
      debugPrint("Error updating profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    // ... (你原有的 _deleteAccount 邏輯保持不變) ...
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

    setState(() => _isSaving = true); // 防止在刪除過程中進行其他操作
    try {
      final user = supa.auth.currentUser;
      if (user == null) {
         _handleUnauthenticatedUser();
         return;
      }
      final uid = user.id;
      // 1) 刪除 users 資料表中的 row
      await supa.from('users').delete().eq('id', uid);
      // 2) 嘗試從 Supabase Auth 刪除用戶 (這是一個更徹底的刪除)
      // 注意：這需要特殊權限，通常是 service_role key，在客戶端不安全。
      // 如果只是想讓用戶無法登入，signOut() 後，下次登入會失敗（因為 users 表沒數據了）
      // 或者你可以實現一個後端函數來處理徹底的 Auth 用戶刪除。
      // 這裡我們先只做 signOut
      await supa.auth.signOut();
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst); // 回首頁
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('帳號已登出，相關資料已刪除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('刪除帳號過程中發生錯誤: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String labelText, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white, // 或者 Colors.grey[50]
        ),
        validator: validator,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _countyController.dispose();
    _districtController.dispose();
    _serviceDistrictController.dispose();
    _serviceTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人檔案'),
        // backgroundColor: Colors.green.shade700, // 與 AppBarTheme 一致
        // iconTheme: const IconThemeData(color: Colors.white),
        // titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      _nameController,
                      '姓名 / 餐廳名稱',
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? '此欄位不可為空'
                              : null,
                    ),
                    _buildTextField(
                      _phoneController,
                      '電話',
                      keyboardType: TextInputType.phone,
                       validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? '電話不可為空'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    Text("地址資訊", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 20),
                    _buildTextField(
                      _countyController,
                      '縣市 (例如：台北市)',
                    ),
                    _buildTextField(
                      _districtController,
                      '鄉鎮市區 (例如：大安區)',
                    ),
                    _buildTextField(
                      _addressController,
                      '詳細街道地址 (例如：復興南路一段390號)',
                       validator: (value) {
                        if (_userRole == 'customer' || _userRole == 'restaurant') { // 外送員的地址可能不是必須的
                          if (value == null || value.trim().isEmpty) {
                            return '詳細地址不可為空';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    if (_userRole == 'restaurant') ...[
                      Text("餐廳特定資訊", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Divider(height: 20),
                      _buildTextField(
                        _serviceTimeController,
                        '服務時間 (例如：每日 10:00 - 20:00)',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_userRole == 'carrier') ...[
                      Text("外送員特定資訊", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Divider(height: 20),
                      _buildTextField(
                        _serviceDistrictController,
                        '主要服務區域 (例如：大安區、信義區、中山區)',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                    ],

                    ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_alt_outlined),
                      label: Text(_isSaving ? '儲存中...' : '儲存變更'),
                      onPressed: _isSaving ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                      label: const Text('刪除帳號',
                          style: TextStyle(color: Colors.redAccent)),
                      onPressed: _isSaving ? null : _deleteAccount,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}