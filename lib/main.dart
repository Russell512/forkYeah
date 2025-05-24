import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'signup_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'restaurant_menu_page.dart';
import 'restaurant_detail_page.dart';

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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePage(),
        '/signup': (_) => const SignupPage(),
        '/login': (_) => const LoginPage(),
        '/profile': (_) => const ProfilePage(), 
        '/menu': (_) => const RestaurantMenuPage(),
      },
      onGenerateRoute: (settings) { // <--- 新增 onGenerateRoute
        if (settings.name == '/restaurant_detail') {
          // 從 settings.arguments 獲取參數
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) {
              return RestaurantDetailPage(
                restaurantId: args['id'] as String,
                restaurantName: args['name'] as String,
              );
            },
          );
        }
        // 如果沒有匹配到，返回 null，讓 routes 處理其他路由
        return null;
      },
    );
  }
}
