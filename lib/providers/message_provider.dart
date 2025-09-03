import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

// メッセージ一覧を取得するStreamProvider
final messagesProvider = StreamProvider<List<Message>>((ref) {
  // 認証状態を監視
  final authState = ref.watch(authStateProvider);
  
  // ユーザーがログインしていない場合は空のStreamを返す
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value([]);
      }
      // FirestoreServiceから最新50件のメッセージを取得
      return FirestoreService.getRecentMessages(limit: 50);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

// 未読メッセージIDのリストを取得するProvider
final unreadMessageIdsProvider = Provider<List<String>>((ref) {
  // メッセージ一覧を監視
  final messagesAsync = ref.watch(messagesProvider);
  
  return messagesAsync.when(
    data: (messages) => FirestoreService.getUnreadMessageIds(messages),
    loading: () => [],
    error: (_, _) => [],
  );
});