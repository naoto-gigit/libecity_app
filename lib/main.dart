import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'widgets/auth_wrapper.dart';

// アプリのエントリーポイント
void main() async {
  // Flutterの初期化を確実に行う
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseの初期化（認証やデータベースを使うために必要）
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Hiveの初期化（ローカルストレージ用）
  await Hive.initFlutter();

  // ProviderScopeで囲むことでRiverpodが使えるようになる
  runApp(const ProviderScope(child: MyApp()));
}

// アプリ全体の設定を行うウィジェット
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libecity Chat',
      // アプリ全体のテーマ設定
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Material Design 3を使用
      ),
      // 認証状態に応じて自動で画面切り替え
      home: const AuthWrapper(),
    );
  }
}
