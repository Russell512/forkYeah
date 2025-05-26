// tool/backfill_embeddings.dart
//
// 把 food_items.image_url 下載 -> localhost:8001/embed -> 512 向量
// 寫回 food_items.embedding

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:dotenv/dotenv.dart' show DotEnv;

Future<void> main() async {
  // 讀 .env
  final env = DotEnv()..load();

  final supa = SupabaseClient(
    env['SUPABASE_URL']!,
    env['SUPABASE_ANON']!,
  );

  final resp = await supa
      .from('food_items')
      .select('id, image_url')
      .is_('embedding', null);

  final items = List<Map<String, dynamic>>.from(resp);
  stdout.writeln('Need to embed ${items.length} images…');

  int done = 0;
  for (final item in items) {
    final id  = item['id'] as String;
    final url = item['image_url'] as String?;

    if (url == null || url.isEmpty) {
      stderr.writeln('✖ 空 URL → $id');
      continue;
    }

    try {
      final bytes = await http.readBytes(Uri.parse(url));
      final emb   = await _embedLocal(bytes);          // ← 呼叫本機

      await supa.from('food_items')
          .update({'embedding': emb}).eq('id', id);

      stdout.writeln('✔ 成功 → $id');
      done++;
    } catch (e) {
      stderr.writeln('✖ 失敗 → $id | $e');
    }
  }
  stdout.writeln('完成：$done / ${items.length}');
}

// ---------------- 本機伺服器 ----------------
Future<List<double>> _embedLocal(List<int> imgBytes) async {
  final req = http.MultipartRequest(
    'POST', Uri.parse('http://localhost:8001/embed'),
  )..files.add(http.MultipartFile.fromBytes(
      'file', imgBytes, filename: 'pic.jpg'));

  final res = await req.send();
  if (res.statusCode != 200) {
    final body = await res.stream.bytesToString();
    throw 'Local server ${res.statusCode}: $body';
  }
  final body = await res.stream.bytesToString();
  final data = jsonDecode(body) as Map<String, dynamic>;
  return (data['embedding'] as List)
      .cast<num>()
      .map((e) => e.toDouble())
      .toList();
}
