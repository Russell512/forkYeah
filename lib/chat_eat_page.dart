import 'package:flutter/material.dart';
import 'services/chat_eat_service.dart'; // 假設這個服務已存在

// 假設 FoodItem 類別已定義在 chat_eat_service.dart 或其他地方
// 如果 FoodItem 也來自 services/chat_eat_service.dart，則不需要重複定義

class ChatEatPage extends StatefulWidget {
  const ChatEatPage({super.key});
  @override
  State<ChatEatPage> createState() => _ChatEatPageState();
}

class _ChatEatPageState extends State<ChatEatPage> {
  final _textController = TextEditingController(); // 改名以更清晰
  final ScrollController _scrollController = ScrollController();
  final List<_Msg> _messages = [];
  bool _isLoadingResponse = false;

  // 推薦查詢列表
  final List<String> _suggestedQueries = [
    "今天好熱，想吃冰涼美食",
    "試試看日本菜吧",
    "我想吃辣的",
    "推薦一些健康的晚餐",
    "附近有什麼甜點？",
  ];

  /// 將對話歷史轉成文字，可傳給 LLM (保持原樣)
  String get _history => _messages
      .map((m) => m.isUser ? 'User: ${m.text}' : 'Bot: ${m.text}')
      .join('\n');

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatEAT'),
        // 如果 main.dart 中有 AppBarTheme，這裡的設定會被覆蓋或可以省略
        // backgroundColor: Colors.green.shade700,
        // iconTheme: const IconThemeData(color: Colors.white),
        // titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment:
                      m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: m.isUser
                          ? Theme.of(context).primaryColor.withOpacity(0.15)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Column(
                      crossAxisAlignment: m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.text,
                          style: const TextStyle(fontSize: 15),
                        ),
                        if (m.food != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.network(
                              m.food!.imageUrl, // 確保 FoodItem 有 imageUrl
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 150,
                                  height: 150,
                                  color: Colors.grey.shade300,
                                  child: const Center(child: Icon(Icons.broken_image, size: 40)),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildSuggestedQueries(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildSuggestedQueries() {
    if (_isLoadingResponse || _messages.isNotEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _suggestedQueries.map((query) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ActionChip(
                avatar: Icon(Icons.send_outlined, size: 16, color: Theme.of(context).primaryColorDark),
                label: Text(query, style: TextStyle(color: Theme.of(context).primaryColorDark)),
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                onPressed: () {
                  // 當推薦按鈕被點擊時，直接調用 _onSend 並傳入查詢文本
                  _handleSend(query);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3))
                ),
                elevation: 1,
                pressElevation: 3,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4.0,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: TextField(
                  controller: _textController, // 使用 _textController
                  decoration: const InputDecoration(
                    hintText: '輸入想吃什麼…',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  ),
                  onSubmitted: (_) => _handleSend(_textController.text.trim()), // 按下 Enter 也發送
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Material(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(24.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(24.0),
                onTap: _isLoadingResponse ? null : () => _handleSend(_textController.text.trim()),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _isLoadingResponse
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 這個方法是你的原始 _onSend，但整合了 isLoadingResponse 和滾動
  // 並能處理來自輸入框和推薦按鈕的文本
  Future<void> _handleSend(String textFromInput) async {
    final text = textFromInput.trim(); // 從參數獲取文本
    if (text.isEmpty || _isLoadingResponse) return;

    setState(() {
      _messages.add(_Msg(isUser: true, text: text));
      _isLoadingResponse = true;
    });

    // 如果是從 TextField 發送的，則清空 TextField
    if (_textController.text == text) {
        _textController.clear();
    }
    _scrollToBottom();

    try {
      // 調用你原始的 ChatEatService.chat
      final res = await ChatEatService.chat(text, history: _history);
      if (mounted) {
        setState(() {
          _messages.add(_Msg(
            isUser: false,
            text: res.reply,
            food: res.food,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_Msg(
            isUser: false,
            text: "發生錯誤，請稍後再試。", // 簡化錯誤訊息
          ));
        });
        // 可以考慮在這裡用 SnackBar 顯示更詳細的錯誤
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("錯誤: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingResponse = false;
        });
        _scrollToBottom();
      }
    }
  }
}

// _Msg 類別 (保持原樣，但確保 FoodItem 類型已定義或從服務中引入)
class _Msg {
  final bool isUser;
  final String text;
  final FoodItem? food; // FoodItem 類型需要被定義
  _Msg({required this.isUser, required this.text, this.food});
}

// --------------------------------------------------------------------
// !!! 重要 !!!
// 以下是你需要確保存在於 'services/chat_eat_service.dart'
// 或其他被正確引用的檔案中的內容。
// 我不會在這裡提供這些內容的實現，因為你希望保留你自己的邏輯。
// --------------------------------------------------------------------

/*
// 範例：在 services/chat_eat_service.dart 中可能需要的定義
// (你需要根據你的實際情況調整)

class FoodItem {
  final String id;
  final String name;
  final String imageUrl;
  // 其他可能的屬性...

  FoodItem({required this.id, required this.name, required this.imageUrl});

  // 可能有 fromJson 等工廠構造函數
}

class ChatResponse {
  final String reply;
  final FoodItem? food;

  ChatResponse({required this.reply, this.food});

  // 可能有 fromJson 等工廠構造函數
}

class ChatEatService {
  static Future<ChatResponse> chat(String message, {String? history}) async {
    // 你原來的 LLM 調用和資料庫查詢邏輯會在這裡
    // ...
    // 返回一個 ChatResponse 實例
    // 例如:
    // final llmReply = await _callLLM(message, history);
    // final foodItem = await _findFoodInDB(llmReply.suggestedFoodName);
    // return ChatResponse(reply: llmReply.text, food: foodItem);
    throw UnimplementedError("你需要實現 ChatEatService.chat 的邏輯");
  }
}
*/