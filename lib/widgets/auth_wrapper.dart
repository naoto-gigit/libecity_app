import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/chat_list_screen.dart';

// 認証状態によって画面を自動切り替えするウィジェット
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // authStateProviderを監視（ここがポイント！）
    final authState = ref.watch(authStateProvider);

    // authStateProvider が変わると自動でここが再実行される
    return authState.when(
      // データ読み込み中
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),

      // エラー発生時
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('エラーが発生しました: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // 再読み込み（戻り値を適切に処理）
                  ref.invalidate(authStateProvider);
                },
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),

      // データ取得成功時
      data: (user) {
        if (user == null) {
          // ユーザーがログインしていない → ログイン画面
          return const LoginScreen();
        } else {
          // ユーザーがログインしている → チャット一覧画面
          return const ChatListScreen();
        }
      },
    );
  }
}
