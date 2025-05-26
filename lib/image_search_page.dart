import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'services/image_embed_service.dart';
import 'services/image_search_service.dart';

class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({super.key});

  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage> {
  final _picker = ImagePicker();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<void> _pickAndSearch(ImageSource src) async {
    final file = await _picker.pickImage(source: src);
    if (file == null) return;

    setState(() => _loading = true);
    try {
      final bytes = await file.readAsBytes();
      final emb = await ImageEmbedService.embed(bytes);
      final hits = await ImageSearchService.search(emb);
      setState(() => _results = hits);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('搜尋失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('以圖搜菜')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('相簿選擇'),
                onPressed: () => _pickAndSearch(ImageSource.gallery),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照'),
                onPressed: () => _pickAndSearch(ImageSource.camera),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(child: Text('尚無結果'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return ListTile(
                            leading: CachedNetworkImage(
                              imageUrl: r['image_url'] as String,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                            title: Text(r['name'] as String),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
