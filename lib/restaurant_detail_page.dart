// lib/restaurant_detail_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// RestaurantDetailPage 是一個有狀態 Widget，因為它需要加載和顯示特定餐廳的商品
class RestaurantDetailPage extends StatefulWidget {
  final String restaurantId; // 接收餐廳 ID 作為參數
  final String restaurantName; // 接收餐廳名稱作為參數 (方便顯示在 AppBar)

  const RestaurantDetailPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  final supa = Supabase.instance.client;
  List<Map<String, dynamic>> _foodItems = []; // 儲存該餐廳的商品列表
  bool _isLoading = true; // 標誌是否正在加載數據

  @override
  void initState() {
    super.initState();
    _loadFoodItems(); // 頁面初始化時加載商品數據
  }

  Future<void> _loadFoodItems() async {
    setState(() => _isLoading = true); // 開始加載，顯示進度條
    try {
      // 從 'food_items' 表中選取所有欄位，並篩選出屬於當前 restaurantId 的商品
      final data = await supa
          .from('food_items')
          .select()
          .eq('restaurant_id', widget.restaurantId) // 使用傳入的餐廳 ID
          .order('name', ascending: true); // 按商品名稱排序

      if (mounted) {
        setState(() {
          _foodItems = List<Map<String, dynamic>>.from(data);
          _isLoading = false; // 加載完成
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false); // 加載失敗，也結束加載狀態
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加載商品失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName), // 顯示餐廳名稱作為標題
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // 加載中顯示進度條
          : _foodItems.isEmpty
          ? const Center(child: Text('此餐廳目前沒有商品')) // 沒有商品時顯示提示
          : ListView.builder( // 顯示商品列表
        padding: const EdgeInsets.all(12),
        itemCount: _foodItems.length,
        itemBuilder: (context, index) {
          final item = _foodItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 商品圖片
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: (item['image_url'] as String?)?.isNotEmpty ?? false
                        ? Image.network(
                      item['image_url'] as String,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 40),
                          ),
                    )
                        : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['description'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${item['price']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        // TODO: 在這裡添加「加入購物車」按鈕
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}