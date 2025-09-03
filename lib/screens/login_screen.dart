import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ログイン/新規登録画面
/// 
/// View層。メール/パスワード認証のUIを提供。
/// エラーメッセージは日本語化済み。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // テキスト入力を管理するコントローラー
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ローディング中かどうかのフラグ
  bool _isLoading = false;

  // ログインか新規登録かのモード切り替え
  bool _isLoginMode = true;

  // Firebase Authのインスタンス
  final _auth = FirebaseAuth.instance;

  /// ログイン/新規登録処理を実行
  /// 
  /// モード（_isLoginMode）に応じて処理を切り替え。
  /// FirebaseAuthExceptionは日本語エラーメッセージに変換。
  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 入力チェック
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスとパスワードを入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLoginMode) {
        // ログイン処理
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // 新規登録処理
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      // 成功したらチャット画面へ遷移（後で実装）
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isLoginMode ? 'ログインしました' : '登録しました')),
        );
      }
    } on FirebaseAuthException catch (e) {
      // エラーメッセージを日本語化
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'ユーザーが見つかりません';
          break;
        case 'wrong-password':
          message = 'パスワードが間違っています';
          break;
        case 'email-already-in-use':
          message = 'このメールアドレスは既に使用されています';
          break;
        case 'weak-password':
          message = 'パスワードが弱すぎます（6文字以上必要）';
          break;
        case 'invalid-email':
          message = 'メールアドレスの形式が正しくありません';
          break;
        default:
          message = 'エラーが発生しました: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // メモリリークを防ぐためコントローラーを破棄
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // アプリロゴやタイトル
              const Icon(Icons.chat, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'RealTime Chat',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 48),

              // メールアドレス入力フィールド
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // パスワード入力フィールド
              TextField(
                controller: _passwordController,
                obscureText: true, // パスワードを隠す
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),

              // ログイン/新規登録ボタン
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLoginMode ? 'ログイン' : '新規登録'),
                ),
              ),
              const SizedBox(height: 16),

              // モード切り替えボタン
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                        });
                      },
                child: Text(
                  _isLoginMode ? 'アカウントをお持ちでない方はこちら' : '既にアカウントをお持ちの方はこちら',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
