import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'restaurant_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth$ = Supabase.instance.client
        .auth
        .onAuthStateChange
        .map((e) => e.session);

    return StreamBuilder(
      stream: auth$,
      builder: (context, snap) {
        final user = snap.data?.user;
        final greeting = user != null
            ? '${user.email}，您好！'
            : '歡迎光臨 ForkYeah';
        return Scaffold(
          appBar: AppBar(title: Text(greeting)),
          drawer: _AppDrawer(user: user),
          body: const _RestaurantGrid(),
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
    var r = u.userMetadata?['role'] as String?;
    if (r == null || r.isEmpty) {
      final data =
      await supa.from('users').select('role').eq('id', u.id).single();
      r = data['role'] as String?;
    }
    if (mounted) setState(() => role = r ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: Colors.green),
          child:
          Text('功能選單', style: TextStyle(color: Colors.white, fontSize: 20)),
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
          // 如果是顧客，顯示購物車
          if (role != 'restaurant')
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('我的購物車'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/cart');
              },
            ),
          // 如果是餐廳業者，顯示「我的商品」
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
      ]),
    );
  }
}

class _RestaurantGrid extends StatefulWidget {
  const _RestaurantGrid();

  @override
  State<_RestaurantGrid> createState() => _RestaurantGridState();
}

class _RestaurantGridState extends State<_RestaurantGrid> {
  final supa = Supabase.instance.client;
  List<Map<String, dynamic>> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final data = await supa
          .from('users')
          .select('id, name, email')
          .eq('role', 'restaurant')
          .order('name', ascending: true);
      if (mounted) {
        setState(() =>
        _restaurants = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加載餐廳失敗: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restaurants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _restaurants.length,
      itemBuilder: (context, index) {
        final restaurant = _restaurants[index];
        return _RestaurantCard(
          restaurantId: restaurant['id'] as String,
          restaurantName: restaurant['name'] as String,
        );
      },
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final String restaurantId;
  final String restaurantName;
  const _RestaurantCard({
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  Widget build(BuildContext context) => Card(
    shape:
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(
          context,
          '/restaurant_detail',
          arguments: {
            'id': restaurantId,
            'name': restaurantName,
          },
        );
      },
      child: Center(child: Text(restaurantName)),
    ),
  );
}
