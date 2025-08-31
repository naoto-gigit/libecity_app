import 'package:cloud_firestore/cloud_firestore.dart';

// メッセージのデータモデル
class Message {
  final String id;
  final String text;
  final String senderId;
  final String senderEmail;
  final DateTime timestamp;
  final Map<String, DateTime> readBy;

  const Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderEmail,
    required this.timestamp,
    this.readBy = const {},
  });

  // Firestoreのドキュメントから Message オブジェクトを作成
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // readByフィールドをMap<String, DateTime>に変換
    Map<String, DateTime> readByMap = {};
    if (data['readBy'] != null) {
      final readByData = data['readBy'] as Map<String, dynamic>;
      readByData.forEach((userId, timestamp) {
        if (timestamp is Timestamp) {
          readByMap[userId] = timestamp.toDate();
        }
      });
    }
    
    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      readBy: readByMap,
    );
  }

  // Message オブジェクトを Firestore用のMapに変換
  Map<String, dynamic> toFirestore() {
    // readByをFirestore用のMap<String, Timestamp>に変換
    Map<String, Timestamp> readByTimestamps = {};
    readBy.forEach((userId, dateTime) {
      readByTimestamps[userId] = Timestamp.fromDate(dateTime);
    });
    
    return {
      'text': text,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readByTimestamps,
    };
  }
  
  // 特定のユーザーが既読したかチェック
  bool isReadBy(String userId) {
    return readBy.containsKey(userId);
  }
  
  // 送信者以外で既読していないユーザーがいるかチェック
  bool hasUnreadByOthers(String currentUserId) {
    if (senderId == currentUserId) {
      // 自分が送信者の場合、他のユーザーが読んでいるかチェック
      return readBy.isEmpty || (readBy.length == 1 && readBy.containsKey(currentUserId));
    }
    return false;
  }
}
