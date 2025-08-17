import 'package:cloud_firestore/cloud_firestore.dart';

// メッセージのデータモデル
class Message {
  final String id;
  final String text;
  final String senderId;
  final String senderEmail;
  final DateTime timestamp;

  const Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderEmail,
    required this.timestamp,
  });

  // Firestoreのドキュメントから Message オブジェクトを作成
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  // Message オブジェクトを Firestore用のMapに変換
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}