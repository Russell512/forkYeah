import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'signup_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'restaurant_menu_page.dart';
import 'restaurant_detail_page.dart';
import 'coupon_wheel_page.dart';   // ← 新的折價券轉盤頁

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
      ),
      initialRoute: '/',
      routes: {
        '/': (_)             => const HomePage(),
        '/signup': (_)       => const SignupPage(),
        '/login': (_)        => const LoginPage(),
        '/profile': (_)      => const ProfilePage(),
        '/menu': (_)         => const RestaurantMenuPage(),
        '/coupon_wheel': (_) => const CouponWheelPage(),   // ← 新路由
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/restaurant_detail') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => RestaurantDetailPage(
              restaurantId: args['id'] as String,
              restaurantName: args['name'] as String,
            ),
          );
        }
        return null;
      },
    );
  }
}
