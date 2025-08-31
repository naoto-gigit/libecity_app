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

class _ChatListScreenState extends ConsumerState<ChatListScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  DateTime? _lastMessageTime; // 連続投稿防止用
  List<Message> _currentMessages = []; // 現在表示中のメッセージ

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリがフォアグラウンドに戻ったときに既読を更新
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
    }
  }

  // 未読メッセージを既読にする
  Future<void> _markMessagesAsRead() async {
    if (_currentMessages.isEmpty) return;
    
    // 全自動版メソッドを使用（Service側で未読チェックから更新まで全部やってくれる）
    await FirestoreService.markMessagesAsRead(_currentMessages);
  }

  // メッセージを送信する関数
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    // 入力値検証
    if (text.isEmpty) {
      _showErrorSnackBar('メッセージを入力してください');
      return;
    }

    // 文字数制限（Firestore Rulesと一致）
    if (text.length > 1000) {
      _showErrorSnackBar('メッセージは1000文字以内で入力してください');
      return;
    }

    // 連続投稿の防止（3秒間隔）
    if (_lastMessageTime != null) {
      final timeDiff = DateTime.now().difference(_lastMessageTime!);
      if (timeDiff.inSeconds < 3) {
        _showErrorSnackBar('連続投稿はお控えください（${3 - timeDiff.inSeconds}秒後に再試行）');
        return;
      }
    }

    // 入力値のクリーニング
    final sanitizedText = _sanitizeInput(text);

    setState(() {
      _isLoading = true;
    });

    try {
      await FirestoreService.sendMessage(sanitizedText);
      _messageController.clear();
      _lastMessageTime = DateTime.now(); // 送信時刻を記録

      // 新しいメッセージが送信されたら最下部にスクロール
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('メッセージの送信に失敗しました: $e')));
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

  // 入力値の検証とクリーニング
  String _sanitizeInput(String input) {
    // 実際に必要な処理：
    // 1. 改行の正規化（連続改行を制限）
    String cleaned = input.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 2. 制御文字を除去（見えない文字でレイアウト崩れを防ぐ）
    cleaned = cleaned.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );

    // 3. 前後の空白を削除
    return cleaned.trim();
  }

  // エラーメッセージを表示
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
                  return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];
                _currentMessages = messages; // 現在のメッセージを保存
                
                // 新しいメッセージがあれば自動的に既読にする
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead();
                });

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
                    maxLength: 1000, // 文字数制限を明示
                    decoration: const InputDecoration(
                      hintText: 'メッセージを入力...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      counterText: '', // 文字数カウンターを非表示
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
    final currentUserId = ref.read(authRepositoryProvider).currentUser?.uid;
    
    // 既読状態を判定
    bool showReadStatus = false;
    int readCount = 0;
    
    if (isMyMessage && currentUserId != null) {
      // 自分のメッセージの場合、他のユーザーが読んだかチェック
      readCount = message.readBy.entries
          .where((entry) => entry.key != currentUserId)
          .length;
      showReadStatus = readCount > 0;
    }
    
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMyMessage ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (showReadStatus) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: isMyMessage ? Colors.white70 : Colors.black54,
                  ),
                  if (readCount > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$readCount',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMyMessage ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
