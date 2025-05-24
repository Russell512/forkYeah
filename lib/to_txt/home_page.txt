import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // auth stream：登入 / 登出時 rebuild
    final auth$ =
        Supabase.instance.client.auth.onAuthStateChange.map((e) => e.session);

    return StreamBuilder(
      stream: auth$,
      builder: (context, snap) {
        final user = snap.data?.user;
        final greeting =
            user != null ? '${user.email}，您好！' : '歡迎光臨 ForkYeah';
        return Scaffold(
          appBar: AppBar(title: Text(greeting)),
          drawer: _AppDrawer(user: user),
          body: const _RestaurantGrid(),
        );
      },
    );
  }
}

// ===== Drawer (Stateful，載一次 role 就不閃爍) =====
class _AppDrawer extends StatefulWidget {
  final User? user;
  const _AppDrawer({required this.user});

  @override
  State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer> {
  String role = '';
  final supa = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initRole();
  }

  Future<void> _initRole() async {
    final u = widget.user;
    if (u == null) return;
    // 1) metadata
    var r = u.userMetadata?['role'] as String?;
    // 2) DB fallback (僅第一次查)
    if (r == null || r.isEmpty) {
      final data = await supa.from('users').select('role').eq('id', u.id).single();
      r = data['role'] as String?;
    }
    if (mounted) setState(() => role = r ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.green),
            child: Text('功能選單', style: TextStyle(color: Colors.white)),
          ),
          ListTile(
            leading: const Icon(Icons.home),
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
              leading: const Icon(Icons.app_registration),
              title: const Text('註冊'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/signup');
              },
            ),
          ] else ...[
            if (role == 'restaurant')
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('我的商品'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/menu');
                },
              ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('更改個人檔案'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('登出'),
              onTap: () async {
                await supa.auth.signOut();
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ---- 假資料餐廳 ----
class _RestaurantGrid extends StatelessWidget {
  const _RestaurantGrid();
  @override
  Widget build(BuildContext context) => GridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: const [
          _RestaurantCard('披薩星球'),
          _RestaurantCard('蘭州拉麵'),
          _RestaurantCard('迴轉壽司'),
          _RestaurantCard('豪豪雞排'),
        ],
      );
}

class _RestaurantCard extends StatelessWidget {
  final String name;
  const _RestaurantCard(this.name);
  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          child: Center(child: Text(name)),
        ),
      );
}
