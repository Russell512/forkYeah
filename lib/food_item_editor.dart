import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodItemEditor extends StatefulWidget {
  final Map<String, dynamic>? item;
  const FoodItemEditor({super.key, this.item});

  @override
  State<FoodItemEditor> createState() => _FoodItemEditorState();
}

class _FoodItemEditorState extends State<FoodItemEditor> {
  final supa = Supabase.instance.client;
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  Uint8List? _imgBytes;
  String? _imgPath;
  String? _remoteUrl; // 已有圖片

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _name.text = it['name'] ?? '';
      _desc.text = it['description'] ?? '';
      _price.text = it['price'].toString();
      _remoteUrl = it['image_url'];
    }
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f == null) return;
    _imgBytes = await f.readAsBytes();
    _imgPath = f.path;
    setState(() => _remoteUrl = null); // 預覽新圖
  }

  Future<String?> _uploadImage() async {
    if (_imgBytes == null) return _remoteUrl;
    try {
      final uid = supa.auth.currentUser!.id;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(_imgPath!)}';
      final fullPath = '$uid/$fileName';

      await supa.storage.from('food-images').uploadBinary(
        fullPath,
        _imgBytes!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      return supa.storage.from('food-images').getPublicUrl(fullPath);
    } catch (e) {
      // 上傳失敗
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上傳圖片失敗: $e')));
      return null;
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名稱不可為空')));
      return;
    }
    final url = await _uploadImage();
    if (url == null && _imgBytes != null) return; // 有選圖但上傳失敗

    final data = {
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'price': num.tryParse(_price.text) ?? 0,
      'image_url': url ?? '',
    };

    try {
      if (widget.item == null) {
        data['restaurant_id'] = supa.auth.currentUser!.id;
        await supa.from('food_items').insert(data);
      } else {
        await supa.from('food_items').update(data).eq('id', widget.item!['id']);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗: $e')));
    }
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.item == null ? '新增商品' : '編輯商品')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              InkWell(
                onTap: _pickImage,
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: _imgBytes != null
                      ? Image.memory(_imgBytes!, fit: BoxFit.cover)
                      : (_remoteUrl?.isNotEmpty ?? false)
                          ? Image.network(_remoteUrl!, fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey[300],
                              child: const Center(child: Text('點擊選擇圖片')),
                            ),
                ),
              ),
              const SizedBox(height: 12),
              _field(_name, '名稱'),
              _field(_desc, '描述'),
              _field(_price, '價格', type: TextInputType.number),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _save, child: const Text('儲存')),
            ],
          ),
        ),
      );
}
