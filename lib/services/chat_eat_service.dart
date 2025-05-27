import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'food_search_service.dart';

class ChatEatService {
  /* ---------- OpenRouter ---------- */
  static const _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';
  static const _model = 'mistralai/mistral-7b-instruct';
  static String get _token => dotenv.env['OPENROUTER_TOKEN'] ?? '';

  /// userMsg: 使用者文字  
  /// history: 可以傳對話歷史（目前不做處理，但保留參數供未來使用）
  static Future<ChatEatResponse> chat(String userMsg,
      {String? history}) async {
    // 1) 先拿 top5 相似菜
    final list = await foodSearchService.top5(userMsg);

    // 門檻 0.15 以上直接推薦第一名
    if (list.isNotEmpty && (list.first['similarity'] as num) >= 0.15) {
      return _replyFixed(list.first, why: '這道最符合你的需求！');
    }

    // 2) LLM 介入
    if (_token.isEmpty) {
      return ChatEatResponse(
          reply: '伺服器缺少 OPENROUTER_TOKEN', needMore: true);
    }

    final names = list.map((e) => e['name'] as String).toList();
    final jsonList = jsonEncode(names);

    final prompt = '''
你只能從以下 JSON 清單選出 **一個** 菜名：
$jsonList

請用以下格式回答（兩行，且 name 行不要加引號）：
name: <菜名>
why: <簡短中文理由>

若選名不在清單內，視為錯誤，請重新回答。
使用者需求：「$userMsg」
''';

    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 128,
        'temperature': 0.7
      }),
    );

    if (res.statusCode != 200) {
      return ChatEatResponse(
          reply: '伺服器忙碌（${res.statusCode}），稍後再試。', needMore: true);
    }

    final body = utf8.decode(res.bodyBytes);
    final data = jsonDecode(body);
    final ans = data['choices'][0]['message']['content'] as String;

    // 解析 name
    final m =
        RegExp(r'name:\s*(.+)', caseSensitive: false).firstMatch(ans);
    var picked = m?.group(1)?.trim() ?? '';
    // 去除引號
    picked = picked.replaceAll(RegExp(r'^"+|"+$'), '');

    if (!names.contains(picked)) {
      return ChatEatResponse(reply: ans, needMore: true);
    }

    // 3) 透過 byName 拿到圖片
    final hit = await foodSearchService.byName(picked);
    if (hit == null) {
      return ChatEatResponse(
        reply: '資料庫找不到「$picked」，請再從清單選一個。',
        needMore: true,
      );
    }

    return ChatEatResponse(
      reply: ans,
      needMore: false,
      food: FoodItem(
        id: hit['id'],
        name: hit['name'],
        imageUrl: hit['image_url'],
      ),
    );
  }

  /// 直接推薦固定菜
  static ChatEatResponse _replyFixed(
      Map<String, dynamic> f, {required String why}) {
    final txt = 'name: ${f['name']}\nwhy: $why';
    return ChatEatResponse(
      reply: txt,
      needMore: false,
      food: FoodItem(
        id: f['id'],
        name: f['name'],
        imageUrl: f['image_url'],
      ),
    );
  }
}

class ChatEatResponse {
  final String reply;
  final bool needMore;
  final FoodItem? food;
  ChatEatResponse({
    required this.reply,
    required this.needMore,
    this.food,
  });
}

class FoodItem {
  final String id;
  final String name;
  final String imageUrl;
  FoodItem({
    required this.id,
    required this.name,
    required this.imageUrl,
  });
}
