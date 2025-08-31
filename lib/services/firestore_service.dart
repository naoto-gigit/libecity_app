import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

// Firestoreとのやり取りを管理するサービス
class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // メッセージコレクションへの参照
  static CollectionReference get _messagesCollection =>
      _firestore.collection('messages');

  // メッセージを送信する
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
    );

    try {
      await _messagesCollection.add(message.toFirestore());
    } catch (e) {
      throw Exception('メッセージの送信に失敗しました: $e');
    }
  }

  // メッセージ一覧をリアルタイムで取得する Stream
  static Stream<List<Message>> getMessages() {
    return _messagesCollection
        .orderBy('timestamp', descending: false) // 古い順にソート
        .snapshots() // リアルタイム監視
        .map((snapshot) {
          // Firestore の DocumentSnapshot を Message オブジェクトに変換
          return snapshot.docs.map((doc) {
            return Message.fromFirestore(doc);
          }).toList();
        });
  }

  // 最新のメッセージ N 件を取得
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
  
  // メッセージを既読にする（既読済みなら何もしない）
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
      print('既読の更新に失敗しました: $e');
    }
  }
  
  // 複数のメッセージを一括で既読にする
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
      print('既読の一括更新に失敗しました: $e');
    }
  }
  
  // 未読メッセージのIDリストを取得
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
  
  // メッセージリストを渡して自動で未読のみ既読にする（全自動版）
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
