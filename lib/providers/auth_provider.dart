import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Authインスタンスを提供するProvider
/// 
/// アプリ全体で共有されるFirebaseAuthのシングルトン。
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// 認証状態をリアルタイム監視するStreamProvider
/// 
/// authStateChanges()を監視して、ログイン/ログアウト時に
/// 自動的にUIを更新。AuthWrapperで使用される。
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  // Firebaseの認証状態変化を自動監視
  return auth.authStateChanges();
});

/// 認証操作を提供するProvider
/// 
/// AuthRepositoryクラスのインスタンスを管理。
/// View層からログイン/ログアウト操作を実行する際に使用。
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return AuthRepository(auth);
});

/// 認証関連のビジネスロジックを管理するリポジトリクラス
/// 
/// Provider経由でアクセスされ、認証操作を抽象化。
/// ViewModel層の一部として機能する。
class AuthRepository {
  const AuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// 現在ログイン中のユーザーを取得
  User? get currentUser => _auth.currentUser;

  /// メールとパスワードでログイン
  /// 
  /// FirebaseAuthExceptionが発生した場合はそのままスロー。
  /// View層でエラーハンドリングを行う。
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

  /// メールとパスワードで新規アカウント作成
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

  /// ログアウト処理
  /// 
  /// authStateChanges()が自動的にnullを配信し、
  /// UIがログイン画面に切り替わる。
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
