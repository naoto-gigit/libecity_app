import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Firebase Authのインスタンスを提供するProvider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// 現在のユーザー情報を監視するProvider
// ここがポイント！authStateChanges()をStreamで監視
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  // Firebaseの認証状態変化を自動監視
  return auth.authStateChanges();
});

// 認証操作を提供するProvider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return AuthRepository(auth);
});

// 認証操作を管理するクラス
class AuthRepository {
  const AuthRepository(this._auth);

  final FirebaseAuth _auth;

  // 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  // メールとパスワードでログイン
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow; // エラーは呼び出し元でハンドリング
    }
  }

  // メールとパスワードで新規登録
  Future<User?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  // ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
