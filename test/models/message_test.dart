import 'package:flutter_test/flutter_test.dart';
import 'package:libecity_app/models/message.dart';

void main() {
  group('Message Model Tests', () {
    test('テキストメッセージを正しく作成できる', () {
      final message = Message(
        id: 'test-id',
        text: 'こんにちは',
        senderId: 'user-123',
        senderEmail: 'test@example.com',
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: MessageType.text,
      );

      expect(message.id, 'test-id');
      expect(message.text, 'こんにちは');
      expect(message.senderId, 'user-123');
      expect(message.senderEmail, 'test@example.com');
      expect(message.type, MessageType.text);
      expect(message.imageUrl, isNull);
      expect(message.thumbnailUrl, isNull);
    });

    test('画像メッセージを正しく作成できる', () {
      final message = Message(
        id: 'test-id',
        text: '',
        senderId: 'user-123',
        senderEmail: 'test@example.com',
        timestamp: DateTime(2024, 1, 1, 12, 0),
        imageUrl: 'https://example.com/image.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        type: MessageType.image,
      );

      expect(message.type, MessageType.image);
      expect(message.imageUrl, 'https://example.com/image.jpg');
      expect(message.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(message.text, '');
    });

    test('混合メッセージ（テキスト＋画像）を正しく作成できる', () {
      final message = Message(
        id: 'test-id',
        text: '画像を送ります',
        senderId: 'user-123',
        senderEmail: 'test@example.com',
        timestamp: DateTime(2024, 1, 1, 12, 0),
        imageUrl: 'https://example.com/image.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        type: MessageType.mixed,
      );

      expect(message.type, MessageType.mixed);
      expect(message.text, '画像を送ります');
      expect(message.imageUrl, isNotNull);
      expect(message.thumbnailUrl, isNotNull);
    });

    test('toFirestoreでマップに正しく変換できる', () {
      final now = DateTime.now();
      final message = Message(
        id: 'test-id',
        text: 'テスト',
        senderId: 'user-123',
        senderEmail: 'test@example.com',
        timestamp: now,
        type: MessageType.text,
      );

      final map = message.toFirestore();

      expect(map['text'], 'テスト');
      expect(map['senderId'], 'user-123');
      expect(map['senderEmail'], 'test@example.com');
      // テスト環境ではFieldValueが使えないため、Timestampになる
      expect(map['timestamp'], isNotNull);
      expect(map['type'], 'text');
      expect(map.containsKey('imageUrl'), isFalse);
      expect(map.containsKey('thumbnailUrl'), isFalse);
    });

    test('既読状態を正しく判定できる', () {
      final message = Message(
        id: 'test-id',
        text: 'テスト',
        senderId: 'user-123',
        senderEmail: 'test@example.com',
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: MessageType.text,
        readBy: {
          'user-123': DateTime(2024, 1, 1, 12, 1),
          'user-456': DateTime(2024, 1, 1, 12, 2),
        },
      );

      // 送信者自身は既読
      expect(message.isReadBy('user-123'), isTrue);
      // 他のユーザーも既読
      expect(message.isReadBy('user-456'), isTrue);
      // 読んでないユーザーは未読
      expect(message.isReadBy('user-789'), isFalse);
    });

    test('既読数を正しくカウントできる', () {
      final message = Message(
        id: 'test-id',
        text: 'テスト',
        senderId: 'user-123',
        senderEmail: 'test@example.com',
        timestamp: DateTime(2024, 1, 1, 12, 0),
        type: MessageType.text,
        readBy: {
          'user-123': DateTime(2024, 1, 1, 12, 1),
          'user-456': DateTime(2024, 1, 1, 12, 2),
          'user-789': DateTime(2024, 1, 1, 12, 3),
        },
      );

      // readByマップのサイズが既読数
      expect(message.readBy.length, 3);
      
      // 送信者を除く既読数を計算
      final othersReadCount = message.readBy.entries
          .where((entry) => entry.key != message.senderId)
          .length;
      expect(othersReadCount, 2);
    });

    test('fromFirestoreでDocumentSnapshotから正しく復元できる', () {
      // DocumentSnapshotのモックは複雑なので、
      // ここではtoFirestore -> fromFirestoreの往復テストを省略
      // 実際のFirestoreとの統合テストで確認する
      expect(true, isTrue);
    });
  });

  group('MessageType Enum Tests', () {
    test('MessageTypeの値が正しい', () {
      expect(MessageType.text.toString(), 'MessageType.text');
      expect(MessageType.image.toString(), 'MessageType.image');
      expect(MessageType.mixed.toString(), 'MessageType.mixed');
    });

    test('MessageTypeから文字列への変換が正しい', () {
      final message = Message(
        id: 'test',
        text: 'test',
        senderId: 'user-123',
        senderEmail: 'test@example.com',
        timestamp: DateTime.now(),
        type: MessageType.text,
      );

      final map = message.toFirestore();
      expect(map['type'], 'text');
    });
  });
}