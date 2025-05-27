// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'restaurant_detail_page.dart';
import 'image_search_page.dart';
import 'chat_eat_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth$ = Supabase.instance.client.auth.onAuthStateChange.map((e) => e.session);

    return StreamBuilder(
      stream: auth$,
      builder: (context, snap) {
        final user = snap.data?.user;

        return Scaffold(
          appBar: AppBar(
            title: Text(user?.email ?? 'ForkYeah'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImageSearchPage()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatEatPage()),
                  );
                },
              ),
            ],
          ),
          drawer: _AppDrawer(user: user),
          body: const _RestaurantGrid(), // 正確使用 _RestaurantGrid
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(context, '/coupon_wheel');
            },
            icon: const Icon(Icons.local_activity, color: Colors.white),
            label: const Text('折價券轉盤', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.orange.shade600,
            elevation: 8.0,
          ),
        );
      },
    );
  }
}

class _AppDrawer extends StatefulWidget {
  final User? user;
  const _AppDrawer({required this.user});

  @override
  State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer> {
  String _role = '';
  final supa = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initRole();
  }

  @override
  void didUpdateWidget(_AppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _initRole();
    }
  }

  Future<void> _initRole() async {
    final u = widget.user;
    if (u == null) {
      if (mounted) setState(() => _role = '');
      return;
    }
    String? roleFromMetadata = u.userMetadata?['role'] as String?;
    String? roleFromDb;
    try {
      final data = await supa.from('users').select('role').eq('id', u.id).maybeSingle();
      if (data != null && data['role'] != null) {
        roleFromDb = data['role'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching role from users table for drawer: $e");
    }
    if (mounted) {
      setState(() => _role = roleFromDb ?? roleFromMetadata ?? 'customer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.appBarTheme.backgroundColor ?? Colors.green.shade700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('功能選單', style: TextStyle(color: theme.appBarTheme.foregroundColor ?? Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (widget.user != null)
                  Text(widget.user!.email ?? '', style: TextStyle(color: (theme.appBarTheme.foregroundColor ?? Colors.white).withOpacity(0.7), fontSize: 14)),
                if (_role.isNotEmpty)
                  Text('角色: $_role', style: TextStyle(color: (theme.appBarTheme.foregroundColor ?? Colors.white).withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 8),
              ],
            )
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('首頁'),
            onTap: () => Navigator.pop(context),
          ),
          if (widget.user == null) ...[
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('登入'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
            ),
            ListTile(
              leading: const Icon(Icons.app_registration_outlined),
              title: const Text('註冊'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/signup');
              },
            ),
          ] else ...[
            if (_role == 'customer') ...[
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined),
                title: const Text('我的購物車'),
                onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/cart'); },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('我的訂單 (進行中)'),
                onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/customer_orders'); },
              ),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('歷史訂單'),
                onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/customer_order_history'); },
              ),
            ],
            if (_role == 'restaurant') ...[
              ListTile(
                leading: const Icon(Icons.list_alt_outlined),
                title: const Text('待處理訂單'),
                onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/restaurant_orders'); },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('歷史訂單 (餐廳)'),
                onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/restaurant_order_history'); },
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('我的商品管理'),
                onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/menu'); },
              ),
            ],
            if (_role == 'carrier') ...[
              ListTile(
                leading: const Icon(Icons.two_wheeler_outlined),
                title: const Text('待領取訂單'),
                onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/delivery'); },
              ),
              ListTile(
                leading: const Icon(Icons.history_edu_outlined),
                title: const Text('我的外送記錄'),
                onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/my_orders_history'); }, // 注意這裡的路由
              ),
            ],
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('更改個人檔案'),
              onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/profile'); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('登出', style: TextStyle(color: Colors.redAccent)),
              onTap: () async { await supa.auth.signOut(); if (mounted) Navigator.pop(context); },
            ),
          ],
        ],
      ),
    );
  }
}

// _RestaurantGrid 和 _RestaurantCard 定義一次
class _RestaurantGrid extends StatefulWidget {
  const _RestaurantGrid({super.key}); // <--- 添加 super.key
  @override
  State<_RestaurantGrid> createState() => _RestaurantGridState();
}

class _RestaurantGridState extends State<_RestaurantGrid> {
  final supa = Supabase.instance.client;
  List<Map<String, dynamic>> _restaurants = [];
  bool _isLoading = true;
  @override
  void initState() { super.initState(); _loadRestaurants(); }
  Future<void> _loadRestaurants() async {
    setState(() => _isLoading = true);
    try {
      final data = await supa.from('users').select('id, name, email').eq('role', 'restaurant').order('name');
      if (mounted) {
        setState(() { _restaurants = List<Map<String, dynamic>>.from(data); _isLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加載餐廳失敗: $e')));
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_restaurants.isEmpty && !_isLoading) return const Center(child: Text('目前沒有餐廳可顯示。'));
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.8,
      ),
      itemCount: _restaurants.length,
      itemBuilder: (context, index) {
        final r = _restaurants[index];
        return _RestaurantCard(
          restaurantId: r['id'] as String,
          restaurantName: r['name'] as String? ?? '未命名餐廳',
        );
      },
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final String restaurantId;
  final String restaurantName;
  const _RestaurantCard({ required this.restaurantId, required this.restaurantName, super.key }); // <--- 添加 super.key
  @override
  Widget build(BuildContext context) {
    final seed = restaurantId.hashCode % 1000;
    final imageUrl = 'https://picsum.photos/seed/$seed/200/100';
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: () {
          Navigator.pushNamed(context, '/restaurant_detail', arguments: {'id': restaurantId, 'name': restaurantName});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CachedNetworkImage(
                imageUrl: imageUrl, height: 100, fit: BoxFit.cover,
                placeholder: (context, url) => Container(height: 100, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0))),
                errorWidget: (context, url, error) => Container(height: 100, color: Colors.grey[300], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40))),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    restaurantName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}