import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/message.dart';
import '../services/firestore_service.dart';

// チャット画面（メッセージのやり取りができる画面）
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // メッセージを送信する関数
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirestoreService.sendMessage(text);
      _messageController.clear();
      
      // 新しいメッセージが送信されたら最下部にスクロール
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メッセージの送信に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // メッセージリストの最下部にスクロール
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.read(authRepositoryProvider);
    final currentUser = authRepo.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Libecity Chat'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authRepo.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // メッセージ一覧
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: FirestoreService.getRecentMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('エラーが発生しました: ${snapshot.error}'),
                  );
                }
                
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('まだメッセージがありません\n最初のメッセージを送ってみましょう！'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMyMessage = message.senderId == currentUser?.uid;
                    
                    return _buildMessageBubble(message, isMyMessage);
                  },
                );
              },
            ),
          ),
          
          // メッセージ入力欄
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'メッセージを入力...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _isLoading
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send),
                        color: Colors.blue,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // メッセージバブルを作成する関数
  Widget _buildMessageBubble(Message message, bool isMyMessage) {
    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMyMessage ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMyMessage) ...[
              Text(
                message.senderEmail,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.text,
              style: TextStyle(
                color: isMyMessage ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: isMyMessage ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}