import 'package:cloud_firestore/cloud_firestore.dart';

/// メッセージタイプの列挙型
enum MessageType { 
  text,   // テキストのみ
  image,  // 画像のみ
  mixed   // テキスト + 画像
}

/// チャットメッセージのデータモデル
/// 
/// Firestoreとのマッピングを担当し、メッセージの基本的な振る舞いを定義
class Message {
  final String id;                      // Firestore Document ID
  final String text;                    // メッセージ本文
  final String senderId;                // 送信者のUID
  final String senderEmail;             // 送信者のメールアドレス
  final DateTime timestamp;             // 送信時刻
  final Map<String, DateTime> readBy;   // 既読ユーザーと既読時刻のマップ
  final String? imageUrl;               // フルサイズ画像のURL（オプション）
  final String? thumbnailUrl;           // サムネイル画像のURL（オプション）
  final MessageType type;               // メッセージのタイプ

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

  /// Firestoreドキュメントから Message インスタンスを生成
  /// 
  /// Timestamp型の変換やnullチェックなど、Firestoreとの変換処理を担当
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // readByフィールドを Map<String, DateTime> に変換
    // FirestoreのTimestamp型をDartのDateTime型へ変換
    Map<String, DateTime> readByMap = {};
    if (data['readBy'] != null) {
      final readByData = data['readBy'] as Map<String, dynamic>;
      readByData.forEach((userId, timestamp) {
        if (timestamp is Timestamp) {
          readByMap[userId] = timestamp.toDate();
        }
      });
    }
    
    // メッセージタイプの判定ロジック
    MessageType messageType = MessageType.text;
    if (data['type'] != null) {
      // 保存されているtype文字列から列挙型へ変換
      messageType = MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => MessageType.text,
      );
    } else {
      // 後方互換性: typeフィールドがない古いデータの自動判定
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

  /// Message インスタンスをFirestoreで保存可能なMapに変換
  /// 
  /// DateTime型をTimestamp型に変換し、null値を除外する
  Map<String, dynamic> toFirestore() {
    // DateTime型をFirestoreのTimestamp型へ変換
    Map<String, Timestamp> readByTimestamps = {};
    readBy.forEach((userId, dateTime) {
      readByTimestamps[userId] = Timestamp.fromDate(dateTime);
    });
    
    // 必須フィールドを含むMapを構築
    final map = {
      'text': text,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readByTimestamps,
      'type': type.toString().split('.').last,  // enum値を文字列化
    };
    
    // オプショナルフィールドは値がある場合のみ追加
    if (imageUrl != null) {
      map['imageUrl'] = imageUrl!;
    }
    if (thumbnailUrl != null) {
      map['thumbnailUrl'] = thumbnailUrl!;
    }
    
    return map;
  }
  
  /// 指定ユーザーが既読済みかチェック
  bool isReadBy(String userId) {
    return readBy.containsKey(userId);
  }
  
  /// 自分のメッセージが他ユーザーに読まれていないかチェック
  /// 
  /// 主に既読表示のUIロジックで使用
  bool hasUnreadByOthers(String currentUserId) {
    if (senderId == currentUserId) {
      // 自分が送信者の場合、他のユーザーが読んでいるかチェック
      return readBy.isEmpty || (readBy.length == 1 && readBy.containsKey(currentUserId));
    }
    return false;
  }
}
