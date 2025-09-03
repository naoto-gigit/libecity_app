import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

/// Firestoreデータベースとの通信を管理するサービスクラス
/// 
/// ViewModel層の一部として、メッセージの送受信や既読管理などの
/// ビジネスロジックを実装。全てstaticメソッドで構成されている。
class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// メッセージコレクションへの参照を取得
  static CollectionReference get _messagesCollection =>
      _firestore.collection('messages');

  /// テキストメッセージを送信
  /// 
  /// 認証済みユーザーのみ送信可能。メッセージにはユーザー情報と
  /// タイムスタンプが自動的に付与される。
  static Future<void> sendMessage(String text) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('ログインが必要です');
    }

    final message = Message(
      id: '', // Firestoreが自動生成するので空文字
      text: text,
      senderId: user.uid,
      senderEmail: user.email ?? '',
      timestamp: DateTime.now(),
      type: MessageType.text,
    );

    try {
      await _messagesCollection.add(message.toFirestore());
    } catch (e) {
      throw Exception('メッセージの送信に失敗しました: $e');
    }
  }

  /// 画像付きメッセージを送信
  /// 
  /// 画像URLは必須、テキストはオプション。
  /// テキストの有無によってメッセージタイプが自動判定される。
  static Future<void> sendImageMessage({
    String? text,
    required String imageUrl,
    required String thumbnailUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('ログインが必要です');
    }

    // メッセージタイプを判定
    MessageType messageType;
    if (text != null && text.isNotEmpty) {
      messageType = MessageType.mixed; // テキストと画像の両方
    } else {
      messageType = MessageType.image; // 画像のみ
    }

    final message = Message(
      id: '',
      text: text ?? '',
      senderId: user.uid,
      senderEmail: user.email ?? '',
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      type: messageType,
    );

    try {
      await _messagesCollection.add(message.toFirestore());
    } catch (e) {
      throw Exception('画像メッセージの送信に失敗しました: $e');
    }
  }

  /// 全メッセージをリアルタイムで取得
  /// 
  /// Firestoreのsnapshots()を使用してリアルタイム更新を実現。
  /// メッセージは古い順にソートされる。
  static Stream<List<Message>> getMessages() {
    return _messagesCollection
        .orderBy('timestamp', descending: false) // 古い順にソート
        .snapshots() // リアルタイム監視
        .map((snapshot) {
          // FirestoreのDocumentSnapshotをMessageオブジェクトに変換
          return snapshot.docs.map((doc) {
            return Message.fromFirestore(doc);
          }).toList();
        });
  }

  /// 最新メッセージを指定件数取得（デフォルト50件）
  /// 
  /// パフォーマンス向上のため件数制限をつけて取得。
  /// 取得後に表示用として古い順に並び替えて返す。
  static Stream<List<Message>> getRecentMessages({int limit = 50}) {
    return _messagesCollection
        .orderBy('timestamp', descending: true) // 新しい順
        .limit(limit) // 件数制限
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs.map((doc) {
            return Message.fromFirestore(doc);
          }).toList();
          // 表示用に古い順に並び替え
          return messages.reversed.toList();
        });
  }
  
  /// 単一メッセージを既読にする
  /// 
  /// 既読済みの場合は無駄な更新を避けるためスキップ。
  /// readByフィールドにユーザーIDとサーバータイムスタンプを記録。
  static Future<void> markAsRead(String messageId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // まず現在のメッセージを取得して既読状態をチェック
      final doc = await _messagesCollection.doc(messageId).get();
      if (!doc.exists) return;
      
      final message = Message.fromFirestore(doc);
      
      // すでに既読なら何もしない（無駄な更新を防ぐ）
      if (message.isReadBy(user.uid)) {
        return;
      }
      
      // 未読の場合のみ更新
      await _messagesCollection.doc(messageId).update({
        'readBy.${user.uid}': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // エラーログは本番環境では出力しない
      // debugPrint('既読の更新に失敗しました: $e');
    }
  }
  
  /// 複数メッセージを一括で既読にする
  /// 
  /// Firestoreのバッチ処理を使用してパフォーマンスを最適化。
  /// 一度のネットワークリクエストで全ての更新を実行。
  static Future<void> markMultipleAsRead(List<String> messageIds) async {
    final user = _auth.currentUser;
    if (user == null || messageIds.isEmpty) return;
    
    // Firestoreのバッチ処理を使用
    final batch = _firestore.batch();
    
    for (final messageId in messageIds) {
      final docRef = _messagesCollection.doc(messageId);
      batch.update(docRef, {
        'readBy.${user.uid}': FieldValue.serverTimestamp(),
      });
    }
    
    try {
      await batch.commit();
    } catch (e) {
      // エラーログは本番環境では出力しない
      // debugPrint('既読の一括更新に失敗しました: $e');
    }
  }
  
  /// 未読メッセージのIDリストを取得
  /// 
  /// 現在のユーザーがまだ読んでいないメッセージのIDを抽出。
  /// 自分が送信したメッセージは除外される。
  static List<String> getUnreadMessageIds(List<Message> messages) {
    final user = _auth.currentUser;
    if (user == null) return [];
    
    return messages
        .where((message) => 
            message.senderId != user.uid && // 自分が送信したメッセージは除外
            !message.isReadBy(user.uid))    // まだ読んでいないメッセージ
        .map((message) => message.id)
        .toList();
  }
  
  /// メッセージリストから未読を自動判定して既読化
  /// 
  /// View層から呼び出される便利メソッド。
  /// 内部でgetUnreadMessageIdsとmarkMultipleAsReadを組み合わせて使用。
  static Future<void> markMessagesAsRead(List<Message> messages) async {
    if (messages.isEmpty) return;
    
    // 未読メッセージのIDを取得（既存メソッドを再利用）
    final unreadIds = getUnreadMessageIds(messages);
    
    // 未読がある場合のみ一括更新（既存メソッドを再利用）
    if (unreadIds.isNotEmpty) {
      await markMultipleAsRead(unreadIds);
    }
  }
}
