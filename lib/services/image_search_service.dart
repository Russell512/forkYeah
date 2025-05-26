import 'package:supabase_flutter/supabase_flutter.dart';

class ImageSearchService {
  static final _supa = Supabase.instance.client;

  /// 用 512 維向量去 RPC，回傳 [{id,name,image_url,similarity}]
  static Future<List<Map<String, dynamic>>> search(
      List<double> embedding) async {
    final data = await _supa.rpc('match_food_items', params: {
      'query_embedding': embedding,
      'match_threshold': 0.2,
      'match_count': 10,
    });
    return List<Map<String, dynamic>>.from(data);
  }
}
