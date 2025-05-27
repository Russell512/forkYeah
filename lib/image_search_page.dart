// lib/image_search_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/image_embed_service.dart';
import 'services/image_search_service.dart';

class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({super.key});

  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage> {
  final _picker = ImagePicker();
  final _textSearchController = TextEditingController();
  final supa = Supabase.instance.client;

  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  String _currentSearchTerm = "";
  bool _isAddingToCart = false;

  // 以圖搜圖功能 (只定義一次)
  Future<void> _pickAndSearchWithImage(ImageSource src) async {
    final file = await _picker.pickImage(source: src, imageQuality: 85); // 可以稍微降低圖片質量
    if (file == null) return;

    setState(() {
      _loading = true;
      _results = [];
      _currentSearchTerm = "";
      _textSearchController.clear();
    });
    try {
      final bytes = await file.readAsBytes();
      // 假設 ImageEmbedService.embed 返回 Future<List<double>>
      final List<double> emb = await ImageEmbedService.embed(bytes);
      // 假設 ImageSearchService.search 接收 List<double> 並返回 Future<List<Map<String, dynamic>>>
      final List<Map<String, dynamic>> hits = await ImageSearchService.search(emb);
      if (mounted) {
        setState(() => _results = hits);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('以圖搜尋失敗: $e')));
      }
      debugPrint("Image search error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 文字搜尋功能 (只定義一次)
  Future<void> _searchWithText(String searchTerm) async {
    final term = searchTerm.trim();
    if (term.isEmpty) {
      if (mounted) {
        setState(() { _results = []; _currentSearchTerm = ""; });
      }
      return;
    }
    setState(() { _loading = true; _results = []; _currentSearchTerm = term; });
    try {
      final response = await supa
          .from('food_items')
          .select('id, name, image_url, restaurant_id') // 確保選擇了 restaurant_id 以便後續可能使用
          .ilike('name', '%$term%')
          .order('name', ascending: true)
          .limit(20);
      if (mounted) {
        setState(() => _results = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('文字搜尋失敗: $e')));
        setState(() => _results = []);
      }
      debugPrint("Text search error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 加入購物車的邏輯
  Future<void> _addItemToCart(String foodItemId, String foodItemName) async {
    if (_isAddingToCart) return;
    setState(() => _isAddingToCart = true);

    final user = supa.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能加入購物車')));
      }
      setState(() => _isAddingToCart = false);
      return;
    }

    try {
      final cartRes = await supa.from('carts').select('id').eq('user_id', user.id).maybeSingle();
      String cartId;
      if (cartRes == null) {
        final newCart = await supa.from('carts').insert({'user_id': user.id}).select('id').single();
        cartId = newCart['id'] as String;
      } else {
        cartId = cartRes['id'] as String;
      }

      final existingCartItem = await supa
          .from('cart_items')
          .select('id, quantity')
          .eq('cart_id', cartId)
          .eq('food_item_id', foodItemId)
          .maybeSingle();

      if (existingCartItem != null) {
        final currentQuantity = existingCartItem['quantity'] as int;
        await supa
            .from('cart_items')
            .update({'quantity': currentQuantity + 1})
            .eq('id', existingCartItem['id'] as String);
      } else {
        await supa.from('cart_items').insert({
          'cart_id': cartId,
          'food_item_id': foodItemId,
          'quantity': 1,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「$foodItemName」已加入購物車！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加入購物車失敗: $e')));
      }
      debugPrint('Error adding to cart from ImageSearchPage: $e');
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  @override
  void dispose() {
    _textSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜尋美食'),
      ),
      body: Column(
        children: [
          Padding( // <--- 修正 Padding
            padding: const EdgeInsets.all(16.0), // <--- 添加了 padding 參數，並調整了值
            child: Column(
              children: [
                TextField(
                  controller: _textSearchController,
                  decoration: InputDecoration(
                    hintText: '輸入餐點名稱搜尋...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0), // 調整內邊距使清除按鈕更好看
                    suffixIcon: _textSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _textSearchController.clear();
                              _searchWithText("");
                            },
                          )
                        : null,
                  ),
                  onSubmitted: _searchWithText, // 直接傳遞方法
                ),
                const SizedBox(height: 16), // 調整間距
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround, // 調整按鈕間距
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('相簿選圖'),
                      onPressed: _loading ? null : () => _pickAndSearchWithImage(ImageSource.gallery),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('拍照搜尋'),
                      onPressed: _loading ? null : () => _pickAndSearchWithImage(ImageSource.camera),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Padding( // 給提示文字也加點 padding
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _currentSearchTerm.isNotEmpty || _textSearchController.text.isNotEmpty
                                ? '找不到符合「${_currentSearchTerm.isNotEmpty ? _currentSearchTerm : _textSearchController.text}」的結果。\n請嘗試其他關鍵字或圖片。'
                                : '請輸入關鍵字或選擇圖片開始搜尋美食！',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12.0),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          final foodItemId = r['id'] as String;
                          final imageUrl = r['image_url'] as String?;
                          final name = r['name'] as String? ?? '未知餐點';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 70,
                                    height: 70,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: (imageUrl != null && imageUrl.isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0))),
                                              errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image, color: Colors.grey)),
                                            )
                                          : Container(color: Colors.grey[200], child: Icon(Icons.restaurant_menu_outlined, color: Colors.grey[400], size: 30)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        // 你可以選擇在這裡顯示更多信息，例如相似度 r['similarity'] (如果 ImageSearchService 返回了)
                                        // if (r.containsKey('similarity'))
                                        //   Text('相似度: ${(r['similarity'] * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8), // 在文字和按鈕之間加點間距
                                  ElevatedButton( // 改用 ElevatedButton，可以放 Icon
                                    onPressed: _isAddingToCart ? null : () => _addItemToCart(foodItemId, name),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      minimumSize: Size.zero, // 讓按鈕緊湊
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: _isAddingToCart
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.add_shopping_cart_outlined, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}