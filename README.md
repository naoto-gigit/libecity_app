# Libecity Chat

リアルタイムチャットアプリケーション（Flutter + Firebase）

## 🎯 概要

FirebaseとFlutterを使用したリアルタイムチャットアプリです。  
複数端末間でのリアルタイム同期、画像送信、既読機能などを実装しています。

**デモサイト**: [https://libecity-app.firebaseapp.com](https://libecity-app.firebaseapp.com)

## 📱 スクリーンショット

<div align="center">
  <img src="docs/screenshots/login.png" width="250" alt="ログイン画面">
  <img src="docs/screenshots/chat.png" width="250" alt="チャット画面">
  <img src="docs/screenshots/image.png" width="250" alt="画像送信">
</div>

## ✨ 主な機能

### 認証システム
- メール/パスワード認証（Firebase Authentication）
- 認証状態による画面自動切り替え（StreamProvider）

### メッセージング
- リアルタイム送受信（StreamProvider + Firestore）
- 複数端末間の自動同期
- テキスト・画像・混合メッセージ対応

### 既読機能
- 未読メッセージのバッチ処理
- 既読人数表示
- リアルタイム更新

### 画像送信
- 自動リサイズ（最大1920px）
- サムネイル生成（200px）
- アップロード進捗表示
- JPEG変換による容量最適化

## 🛠 使用技術

### フロントエンド
- **Flutter** 3.35.1（Dart）
- **Riverpod** - 状態管理
- **Material Design 3** - UIデザイン

### バックエンド・インフラ
- **Firebase**
  - Authentication - 認証
  - Firestore - リアルタイムDB
  - Storage - 画像保存
  - Hosting - Web版公開
  - Security Rules - セキュリティ

### 開発環境・CI/CD
- **GitHub Actions** - 自動テスト（CI）
- **Unit Test** - 単体テスト
- **Flutter Analyze** - 静的解析

### アーキテクチャ
- **MVVM** - アーキテクチャパターン
- **Repository Pattern** - データ層の抽象化

## 🚀 セットアップ

### 必要な環境
- Flutter 3.35.1以上
- Dart 3.9.0以上
- Firebase CLIツール

### インストール手順

1. リポジトリをクローン
```bash
git clone https://github.com/naoto-gigit/libecity_app.git
cd libecity_app
```

2. 依存関係をインストール
```bash
flutter pub get
```

3. Firebase設定
```bash
# Firebase CLIでログイン
firebase login

# Firebaseプロジェクトを設定
flutterfire configure
```

4. 実行
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# Web
flutter run -d chrome
```

## 🧪 テスト

### Unit Testの実行
```bash
flutter test
```

### コード品質チェック
```bash
flutter analyze
```

### CI/CD
- GitHub Actionsによる自動テスト
- mainブランチへのプッシュで自動実行

## 📝 今後の実装予定

- [ ] ローカルキャッシュ（Hive）
- [ ] プッシュ通知
- [ ] ユーザープロフィール機能
- [ ] グループチャット
- [ ] メッセージ検索

## 🔒 セキュリティ

- Firebase Security Rulesによるアクセス制御
- 入力値検証とサニタイズ
- 連続投稿防止機能
- 認証必須のデータアクセス

## 📄 ライセンス

MIT License

## 👨‍💻 開発者

[GitHub Profile](https://github.com/naoto-gigit)