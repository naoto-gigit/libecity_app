import 'package:cloud_firestore/cloud_firestore.dart';

// メッセージタイプの列挙型
enum MessageType { text, image, mixed }

// メッセージのデータモデル
class Message {
  final String id;
  final String text;
  final String senderId;
  final String senderEmail;
  final DateTime timestamp;
  final Map<String, DateTime> readBy;
  final String? imageUrl;       // フルサイズ画像のURL
  final String? thumbnailUrl;   // サムネイル画像のURL
  final MessageType type;       // メッセージのタイプ

  const Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderEmail,
    required this.timestamp,
    this.readBy = const {},
    this.imageUrl,
    this.thumbnailUrl,
    this.type = MessageType.text,
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
    
    // メッセージタイプを判定
    MessageType messageType = MessageType.text;
    if (data['type'] != null) {
      messageType = MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => MessageType.text,
      );
    } else {
      // 互換性のため、画像がある場合はタイプを自動判定
      if (data['imageUrl'] != null && data['text'] != null && data['text'].isNotEmpty) {
        messageType = MessageType.mixed;
      } else if (data['imageUrl'] != null) {
        messageType = MessageType.image;
      }
    }
    
    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      readBy: readByMap,
      imageUrl: data['imageUrl'],
      thumbnailUrl: data['thumbnailUrl'],
      type: messageType,
    );
  }

  // Message オブジェクトを Firestore用のMapに変換
  Map<String, dynamic> toFirestore() {
    // readByをFirestore用のMap<String, Timestamp>に変換
    Map<String, Timestamp> readByTimestamps = {};
    readBy.forEach((userId, dateTime) {
      readByTimestamps[userId] = Timestamp.fromDate(dateTime);
    });
    
    final map = {
      'text': text,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readByTimestamps,
      'type': type.toString().split('.').last,
    };
    
    // 画像URLがある場合のみ追加
    if (imageUrl != null) {
      map['imageUrl'] = imageUrl!;
    }
    if (thumbnailUrl != null) {
      map['thumbnailUrl'] = thumbnailUrl!;
    }
    
    return map;
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
