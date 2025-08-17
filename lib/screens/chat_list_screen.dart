import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

// チャット一覧画面（ログイン後に表示される画面）
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 認証リポジトリを取得
    final authRepo = ref.read(authRepositoryProvider);
    // 現在のユーザー情報を取得
    final user = authRepo.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Libecity Chat'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // ログアウトボタン
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // ログアウト実行
              await authRepo.signOut();
              // authStateProvider が変化して自動でログイン画面に戻る！
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ユーザー情報表示
            const Icon(
              Icons.chat,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              'ようこそ！',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'ログイン中: ${user?.email ?? "不明"}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            
            // 将来的にチャット一覧がここに表示される
            const Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.construction, size: 48),
                    SizedBox(height: 8),
                    Text('チャット機能は開発中です'),
                    Text('まずはログイン・ログアウトが動作することを確認してください'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}