import 'package:supabase_flutter/supabase_flutter.dart';

class FoodSearchService {
  final _supa = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> top5(String query) async {
    final data =
        await _supa.rpc('top5_food', params: {'q': query}) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// 用 ILIKE（不分大小寫）查單筆，回 null 代表查無
  Future<Map<String, dynamic>?> byName(String name) async {
    final res = await _supa
        .from('food_items')
        .select('id, name, image_url')
        .ilike('name', name)
        .limit(1)
        .maybeSingle();
    return res;
  }
}

final foodSearchService = FoodSearchService();
