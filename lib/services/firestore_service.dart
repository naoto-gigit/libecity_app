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
}
