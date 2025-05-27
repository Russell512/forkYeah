import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p; // 用於獲取文件擴展名
import 'package:supabase_flutter/supabase_flutter.dart';

// 引入你的 ImageEmbedService
// 確保路徑正確
import '../services/image_embed_service.dart'; // <--- 假設的路徑，請確認

class FoodItemEditor extends StatefulWidget {
  final Map<String, dynamic>? item; // 從 food_items 表讀取的現有商品資料
  const FoodItemEditor({super.key, this.item});

  @override
  State<FoodItemEditor> createState() => _FoodItemEditorState();
}

class _FoodItemEditorState extends State<FoodItemEditor> {
  final supa = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>(); // 用於表單驗證 (可選但推薦)
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  Uint8List? _selectedImageBytes; // 用戶新選擇的圖片 bytes
  String? _selectedImagePath;    // 用戶新選擇的圖片路徑 (主要用於獲取擴展名)
  String? _existingImageUrl;     // 編輯模式下，商品已有的遠端圖片 URL

  bool _isSaving = false; // 防止重複點擊儲存

  @override
  void initState() {
    super.initState();
    final currentItem = widget.item;
    if (currentItem != null) {
      _nameController.text = currentItem['name'] ?? '';
      _descriptionController.text = currentItem['description'] ?? '';
      _priceController.text = (currentItem['price'] as num?)?.toString() ?? '';
      _existingImageUrl = currentItem['image_url'] as String?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isSaving) return;
    try {
      final imageFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // 稍微壓縮圖片質量以減少大小
      );
      if (imageFile == null) return;

      final bytes = await imageFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImagePath = imageFile.path;
        _existingImageUrl = null; // 清除已有的遠端圖片預覽，優先顯示新選的
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選擇圖片失敗: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImageIfNecessary() async {
    // 如果沒有新選擇圖片，且已有遠端圖片，則直接返回遠端 URL
    if (_selectedImageBytes == null) {
      return _existingImageUrl;
    }

    // 如果新選擇了圖片，則上傳
    try {
      final userId = supa.auth.currentUser!.id;
      // 使用時間戳和原始擴展名生成唯一文件名
      final fileExtension = p.extension(_selectedImagePath!); // p.extension 會包含 '.'
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final filePath = '$userId/$fileName'; // 在用戶的資料夾下

      await supa.storage.from('food-images').uploadBinary(
            filePath,
            _selectedImageBytes!,
            fileOptions: const FileOptions(
              cacheControl: '3600', // 快取1小時
              upsert: false,        // 如果文件已存在則報錯 (通常希望每次都是新文件)
            ),
          );
      return supa.storage.from('food-images').getPublicUrl(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上傳圖片失敗: $e')),
        );
      }
      return null; // 上傳失敗返回 null
    }
  }

  Future<void> _saveItem() async {
    if (_isSaving) return; // 防止重複提交
    // 簡單的表單驗證 (可以做得更完善)
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('餐點名稱不可為空')));
      return;
    }
    if (num.tryParse(_priceController.text.trim()) == null) {
        ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請輸入有效的價格')));
      return;
    }


    setState(() => _isSaving = true);

    try {
      final imageUrl = await _uploadImageIfNecessary();

      // 即使圖片上傳失敗 (imageUrl 為 null)，如果用戶沒有新選圖片但原本有圖，我們依然可以繼續
      // 但如果用戶新選了圖片卻上傳失敗 (imageUrl 為 null 且 _selectedImageBytes 非 null)，則提示並中止
      if (imageUrl == null && _selectedImageBytes != null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('圖片上傳失敗，無法儲存')));
        }
        setState(() => _isSaving = false);
        return;
      }

      List<double>? imageEmbedding;
      // 只有在新選擇了圖片且圖片成功上傳（或原本就沒有選圖則不需要 embedding）的情況下才生成 embedding
      if (_selectedImageBytes != null && imageUrl != null) {
        try {
          // 為新圖片生成 embedding
          imageEmbedding = await ImageEmbedService.embed(_selectedImageBytes!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('圖片向量化失敗: $e. 餐點仍會儲存，但可能影響以圖搜圖。')),
            );
          }
          // 即使向量化失敗，我們還是可以選擇儲存餐點（不帶 embedding）
          // 或者你可以決定中止儲存，視業務需求而定
        }
      }

      final itemData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': num.parse(_priceController.text.trim()), // 確保是數字
        'image_url': imageUrl ?? _existingImageUrl ?? '', // 優先使用新上傳的，其次是已有的，最後是空字串
        // 'embedding': imageEmbedding, // 直接這樣賦值 Supabase Dart client 會處理 List<double> 到 vector
                                    // 如果 imageEmbedding 是 null，則資料庫中對應欄位也會是 null
      };

      // 只有在 imageEmbedding 成功生成時才加入到 data 中
      // 如果 embedding 是 null，則資料庫中該欄位會是 null，`match_food_items` 函數在比較時會忽略這條記錄
      if (imageEmbedding != null) {
        itemData['embedding'] = imageEmbedding;
      } else if (widget.item != null && _selectedImageBytes == null) {
        // 如果是編輯模式，且沒有選擇新圖片，我們應該保留舊的 embedding (如果有的話)
        // 這需要從 widget.item 中獲取舊的 embedding (假設它以 List<double> 形式存在)
        // final oldEmbedding = widget.item!['embedding'] as List<dynamic>?;
        // if (oldEmbedding != null) {
        //   itemData['embedding'] = oldEmbedding.cast<double>();
        // }
        // 為了簡化，如果編輯時圖片未變，embedding 欄位就不更新。
        // Supabase 的 update 預設只更新你傳遞的欄位。
        // 但如果新圖片向量化失敗，則 embedding 可能會被清空或保持舊值，取決於你的策略。
        // 最安全的做法是：如果圖片改變，則必須有新的 embedding，否則不更新 embedding 欄位。
        // 或者，如果圖片改變但 embedding 失敗，將 embedding 設為 null。
      }


      if (widget.item == null) { // 新增商品
        itemData['restaurant_id'] = supa.auth.currentUser!.id;
        await supa.from('food_items').insert(itemData);
      } else { // 更新商品
        // 確保只在 embedding 需要更新時才包含它
        // 如果 imageEmbedding 為 null 且是編輯模式且圖片未更改，則不應發送 embedding 欄位以保留舊值
        if (imageEmbedding == null && _selectedImageBytes == null) {
          itemData.remove('embedding'); // 不更新 embedding 欄位，保留資料庫中的舊值
        }
        await supa.from('food_items').update(itemData).eq('id', widget.item!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('餐點已儲存！')),
        );
        Navigator.pop(context, true); // 返回 true 表示操作成功
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存餐點失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String labelText, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator, // 可選的驗證器
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField( // 使用 TextFormField 以便進行驗證
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? '新增商品' : '編輯商品'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveItem, // 正在儲存時禁用按鈕
            tooltip: '儲存',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form( // 將表單包裹在 Form widget 中以使用 validator
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _pickImage,
                child: AspectRatio( // 保持圖片區域的寬高比
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: _selectedImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7.0),
                            child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover))
                        : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(7.0),
                                child: Image.network(_existingImageUrl!, fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                    const Center(child: Text('無法載入圖片')),
                                ))
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('點擊選擇圖片', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                _nameController,
                '餐點名稱',
                validator: (value) => (value == null || value.trim().isEmpty) ? '名稱不可為空' : null,
              ),
              _buildTextField(
                _descriptionController,
                '餐點描述 (選填)',
                maxLines: 3,
              ),
              _buildTextField(
                _priceController,
                '價格',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return '價格不可為空';
                  if (num.tryParse(value.trim()) == null) return '請輸入有效的數字';
                  if (num.parse(value.trim()) < 0) return '價格不能為負';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                label: Text(_isSaving ? '儲存中...' : '儲存餐點'),
                onPressed: _isSaving ? null : () {
                  if (_formKey.currentState!.validate()) { // 觸發表單驗證
                    _saveItem();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}