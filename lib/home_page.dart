// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 引入你新的餐廳詳細頁面
import 'restaurant_detail_page.dart'; // <--- 確保這行有新增

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
          body: const _RestaurantGrid(), // 這裡保持呼叫 _RestaurantGrid
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

// ---- 真實餐廳列表 ----
// _RestaurantGrid 轉換為 StatefulWidget 以加載非同步數據
class _RestaurantGrid extends StatefulWidget {
  const _RestaurantGrid();

  @override
  State<_RestaurantGrid> createState() => _RestaurantGridState();
}

class _RestaurantGridState extends State<_RestaurantGrid> {
  final supa = Supabase.instance.client; // 獲取 Supabase 客戶端實例
  List<Map<String, dynamic>> _restaurants = []; // 儲存從 Supabase 獲取的餐廳列表

  @override
  void initState() {
    super.initState();
    _loadRestaurants(); // 頁面初始化時加載餐廳數據
  }

  Future<void> _loadRestaurants() async {
    try {
      // 從 'users' 表中選取 id, name, email，並篩選出 role 為 'restaurant' 的用戶
      final data = await supa
          .from('users')
          .select('id, name, email') // 假設這些是餐廳需要顯示的資訊
          .eq('role', 'restaurant')
          .order('name', ascending: true); // 按名稱排序

      if (mounted) {
        setState(() {
          // 將查詢結果轉換為 List<Map<String, dynamic>>
          _restaurants = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      // 加載失敗時顯示錯誤訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加載餐廳失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) { // <--- 這裡很重要，檢查是否包含此 build 方法
    if (_restaurants.isEmpty) { // 如果沒有加載到數據 (_restaurants 為空)，顯示加載中或沒有數據
      return const Center(child: CircularProgressIndicator()); // 顯示一個圓形進度條
      // 或者：return const Center(child: Text('沒有餐廳資料')); // 如果確定沒有數據
    }

    return GridView.builder( // <--- 這裡改為 GridView.builder，用於動態生成列表
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 每行兩列
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0, // 確保卡片是正方形
      ),
      itemCount: _restaurants.length, // 網格項的數量，來自加載的餐廳列表
      itemBuilder: (context, index) {
        final restaurant = _restaurants[index];
        // 將 _RestaurantCard 傳遞真實的餐廳數據
        return _RestaurantCard(
          restaurantId: restaurant['id'] as String, // 傳遞餐廳 ID
          restaurantName: restaurant['name'] as String, // 傳遞餐廳名稱
          // 如果 'email' 也是需要的資訊，可以傳遞：restaurantEmail: restaurant['email'] as String,
        );
      },
    );
  }
}

// _RestaurantCard 現在將接收餐廳 ID 和名稱
class _RestaurantCard extends StatelessWidget {
  final String restaurantId; // 新增餐廳 ID
  final String restaurantName; // 餐廳名稱
  const _RestaurantCard({required this.restaurantId, required this.restaurantName});

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () { // <--- 新增這裡的 onTap 邏輯
        Navigator.pushNamed(
          context,
          '/restaurant_detail', // 導航到新的詳細頁面路由
          arguments: { // 傳遞參數給詳細頁面
            'id': restaurantId,
            'name': restaurantName,
          },
        );
      },
      child: Center(child: Text(restaurantName)), // 顯示真實餐廳名稱
    ),
  );
}