import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../models/message.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

/// メインチャット画面
/// 
/// View層。メッセージの表示、送信、画像アップロードを担当。
/// WidgetsBindingObserverを使用してアプリのライフサイクルを監視。
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;
  DateTime? _lastMessageTime; // 連続投稿防止用（3秒間隔）

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

  /// アプリのライフサイクル監視
  /// バックグラウンドから復帰時に既読処理を実行
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリがフォアグラウンドに戻ったときに既読を更新
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
    }
  }

  /// 未読メッセージを既読にする
  /// Providerからメッセージを取得し、他人の未読のみバッチ処理
  Future<void> _markMessagesAsRead() async {
    // ref.readで一回だけ取得（rebuildしない）
    final messagesAsync = ref.read(messagesProvider);
    
    // データがあるときだけ既読処理
    messagesAsync.whenData((messages) async {
      if (messages.isNotEmpty) {
        await FirestoreService.markMessagesAsRead(messages);
      }
    });
  }

  /// テキストメッセージを送信
  /// 
  /// 入力値検証（文字数、連続投稿）を行い、
  /// FirestoreServiceを呼び出して送信。
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

  /// メッセージリストの最下部にスクロール
  /// 新メッセージ送信後に自動スクロールでUX向上
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 入力値の検証とクリーニング
  /// XSS対策とレイアウト崩れ防止のためのテキスト処理
  String _sanitizeInput(String input) {
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

  /// エラーメッセージをSnackBarで表示
  /// mountedチェックで安全にUI更新
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// フルサイズ画像をモーダルダイアログで表示
  /// InteractiveViewerでピンチズームも対応
  void _showFullSizeImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景をタップで閉じる
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(color: Colors.black54),
              ),
              
              // 画像表示（ピンチズーム可能）
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  },
                ),
              ),
              // 閉じるボタン
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 画像選択からアップロードまでの一連の処理
  /// 
  /// ImagePickerで選択 → StorageServiceでアップロード → 
  /// FirestoreServiceでメッセージ送信のフロー。
  Future<void> _pickAndSendImage() async {
    try {
      // ImagePickerを使ってギャラリーから画像を選択
      // maxWidthとimageQualityで事前に最適化
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,  // 最大幅を制限
        imageQuality: 85, // 画質を調整
      );

      if (pickedFile == null) {
        return; // キャンセルされた場合
      }

      setState(() {
        _isUploadingImage = true;
        _uploadProgress = 0.0;
      });

      // StorageServiceで画像をFirebase Storageにアップロード
      // フルサイズとサムネイルの2種類が生成される
      final Map<String, String> urls = await StorageService.uploadImageWithProgress(
        pickedFile,
        (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      // アップロード完了後、FirestoreにメッセージDocumentを作成
      // imageUrlとthumbnailUrlを含むメッセージとして保存
      final text = _messageController.text.trim();
      await FirestoreService.sendImageMessage(
        text: text.isNotEmpty ? text : null,
        imageUrl: urls['imageUrl']!,
        thumbnailUrl: urls['thumbnailUrl']!,
      );

      // 画像と一緒にテキストが送信された場合は入力欄をクリア
      if (text.isNotEmpty) {
        _messageController.clear();
      }

      // 新メッセージ送信後、自動的にチャット末尾へスクロール
      // UX向上のため100ms遅延させて確実に表示を更新
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      }
    } catch (e) {
      _showErrorSnackBar('画像の送信に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  /// メインのbuildメソッド
  @override
  Widget build(BuildContext context) {
    // 認証情報を取得（ref.readで一回だけ）
    final authRepo = ref.read(authRepositoryProvider);
    final currentUser = authRepo.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RealTime Chat'),
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
          // メッセージ一覧表示エリア（Expandedで残り領域全体を使用）
          Expanded(
            // StreamProviderでメッセージをリアルタイム監視
            // Firestoreの変更を自動検知してUIを再構築
            child: ref.watch(messagesProvider).when(
              data: (messages) {
                // 画面描画完了後に既読処理を非同期で実行
                // addPostFrameCallbackで描画を妨げない
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead();
                });

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('まだメッセージがありません\n最初のメッセージを送ってみましょう！'),
                  );
                }

                // メッセージリストをListView.builderで効率的に表示
                // 大量のメッセージでもパフォーマンスを維持
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('エラーが発生しました: $error'),
              ),
            ),
          ),

          // メッセージ入力エリア（下部固定）
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // 画像アップロード中の進捗バー表示
                // LinearProgressIndicatorで0〜100%を視覚化
                if (_isUploadingImage)
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                // テキスト入力と送信ボタンを横並びに配置
                Row(
                  children: [
                    // 画像選択ボタン（アップロード中は無効化）
                    IconButton(
                      onPressed: _isUploadingImage ? null : _pickAndSendImage,
                      icon: const Icon(Icons.photo),
                      color: Colors.blue,
                    ),
                    
                    // テキスト入力フィールド（残り幅全体を使用）
                    // 最大1000文字制限でFirestore Rulesと整合性確保
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLength: 1000, // Firestore Rulesと一致
                        decoration: const InputDecoration(
                          hintText: 'メッセージを入力...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          counterText: '', // 文字数カウンター非表示
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isUploadingImage, // アップロード中は無効化
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // 送信ボタン（処理中はProgressIndicator表示）
                    _isLoading || _isUploadingImage
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// メッセージバブルUIを生成
  /// 送信者に応じて色や位置を調整、既読表示も制御
  Widget _buildMessageBubble(Message message, bool isMyMessage) {
    final currentUserId = ref.read(authRepositoryProvider).currentUser?.uid;
    
    // 既読状態を判定（自分が送信したメッセージのみ表示）
    // 他ユーザーがreadByに含まれているかチェック
    bool showReadStatus = false;
    int readCount = 0;
    
    if (isMyMessage && currentUserId != null) {
      // readByマップから自分以外のユーザー数をカウント
      // 複数人が読んだ場合は人数も表示
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
            
            // サムネイル画像表示部分
            // タップするとフルサイズ画像をモーダルで表示
            if (message.thumbnailUrl != null) ...[
              GestureDetector(
                onTap: () {
                  // タップ時にフルサイズ画像モーダルを起動
                  // InteractiveViewerでピンチズーム対応
                  _showFullSizeImage(message.imageUrl ?? message.thumbnailUrl!);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.thumbnailUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.error, color: Colors.red),
                      );
                    },
                  ),
                ),
              ),
              if (message.text.isNotEmpty) const SizedBox(height: 8),
            ],
            
            // テキストメッセージ表示（画像のみの場合は非表示）
            if (message.text.isNotEmpty)
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
