import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';   // ← 新增

/// 將圖片 bytes 傳給本機 CLIP 伺服器，拿到 512 維向量
class ImageEmbedService {
  static const _endpoint = 'http://localhost:8001/embed';

  static Future<List<double>> embed(Uint8List bytes) async {
    final req = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'q.jpg',
          contentType: MediaType('image', 'jpeg'),   // ← 這行現在能解析
        ),
      );

    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw 'Embed server ${res.statusCode}: $body';
    }
    final data =
        (jsonDecode(body) as Map<String, dynamic>)['embedding'] as List;
    return data.cast<num>().map((e) => e.toDouble()).toList();
  }
}
