import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

/// メッセージ一覧をリアルタイム取得するStreamProvider
/// 
/// 認証状態と連携し、ログイン中のみFirestoreからデータ取得。
/// ログアウト時は自動的に空リストを配信。
/// View層のStreamBuilderを置き換えて使用される。
final messagesProvider = StreamProvider<List<Message>>((ref) {
  // 認証状態を監視
  final authState = ref.watch(authStateProvider);
  
  // 認証状態に応じて適切なStreamを返す
  return authState.when(
    data: (user) {
      if (user == null) {
        // 未ログイン時は空のStream
        return Stream.value([]);
      }
      // ログイン時は最新50件のメッセージを取得
      return FirestoreService.getRecentMessages(limit: 50);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

/// 未読メッセージIDのリストを提供するProvider
/// 
/// messagesProviderの派生Provider。
/// 現在のユーザーが未読のメッセージIDをリアルタイムで提供。
/// 将来的に未読数バッジなどの実装に使用可能。
final unreadMessageIdsProvider = Provider<List<String>>((ref) {
  // メッセージ一覧を監視
  final messagesAsync = ref.watch(messagesProvider);
  
  return messagesAsync.when(
    data: (messages) => FirestoreService.getUnreadMessageIds(messages),
    loading: () => [],
    error: (_, _) => [],
  );
});