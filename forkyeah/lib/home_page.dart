import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supa = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final user = supa.auth.currentUser;
    final greeting = user != null ? '${user.email}，您好！' : '歡迎光臨 ForkYeah';

    return Scaffold(
      appBar: AppBar(
        title: Text(greeting),
        //leading: IconButton(
        //  icon: const Icon(Icons.menu),
        //  onPressed: () => Scaffold.of(context).openDrawer(),
        //),
      ),
      drawer: Drawer(
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
            if (user == null) ...[
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
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('登出'),
                onTap: () async {
                  await supa.auth.signOut();
                  if (mounted) setState(() {});
                  Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),

      // ↓ 假資料餐廳區塊，可自行改成 ListView.builder 讀 DB
      body: GridView.count(
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
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final String name;
  const _RestaurantCard(this.name);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {}, // TODO: 點進菜單頁
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(name, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
