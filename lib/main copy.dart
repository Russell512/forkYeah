// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 頁面引入
import 'home_page.dart';
import 'signup_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'restaurant_menu_page.dart';
import 'restaurant_detail_page.dart';
import 'coupon_wheel_page.dart';
import 'cart_page.dart';
import 'delivery_page.dart';
import 'my_orders_page.dart';
import 'customer_orders_page.dart';
import 'customer_order_detail_page.dart';
import 'restaurant_active_orders_page.dart';
import 'customer_order_history_page.dart'; // <--- 確保引入 CustomerOrderHistoryPage

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON']!,
  );

  runApp(const ForkYeahApp());
}

class ForkYeahApp extends StatelessWidget {
  const ForkYeahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForkYeah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_)                 => const HomePage(),
        '/signup': (_)           => const SignupPage(), // 假設建構子是 const
        '/login': (_)            => const LoginPage(),  // 假設建構子是 const
        '/profile': (_)          => const ProfilePage(),
        '/menu': (_)             => const RestaurantMenuPage(),
        '/coupon_wheel': (_)     => const CouponWheelPage(),
        '/cart': (_)             => const CartPage(),
        '/delivery': (_)         => const DeliveryPage(),
        '/my_orders': (_)        => const MyOrdersPage(),
        '/customer_orders':(_)   => const CustomerOrdersPage(),
        '/restaurant_orders':(_) => const RestaurantActiveOrdersPage(),
        '/customer_order_history':(_) => const CustomerOrderHistoryPage(), // <--- 新增這一行路由定義
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/restaurant_detail') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('id') && args.containsKey('name')) {
            return MaterialPageRoute(
              builder: (_) => RestaurantDetailPage(
                restaurantId: args['id'] as String,
                restaurantName: args['name'] as String,
              ),
            );
          }
        }
        if (settings.name == '/customer_order_detail') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('order_id')) {
            final orderId = args['order_id'] as String;
            return MaterialPageRoute(
              builder: (_) => CustomerOrderDetailPage(orderId: orderId),
            );
          }
          // 如果缺少 order_id，可以返回一個錯誤提示頁面或 null
          return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("錯誤：導航到訂單詳情頁時缺少訂單ID"))));
        }
        // 如果沒有匹配的路由，可以返回一個預設的未知路由頁面，或者 null 讓 Flutter 處理
        // return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("頁面未找到"))));
        return null;
      },
    );
  }
}