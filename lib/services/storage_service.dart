import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

// Firebase Storageとの連携を管理するサービス
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 画像をアップロードしてURLを返す
  static Future<Map<String, String>> uploadImage(XFile imageFile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('ユーザーがログインしていません');
    }

    try {
      // 画像データを読み込み
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // 画像をデコード
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('画像のデコードに失敗しました');
      }

      // タイムスタンプを生成（ファイル名用）
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // フルサイズ画像をリサイズ（最大1920px）
      final img.Image fullSizeImage = _resizeImage(originalImage, 1920);
      final Uint8List fullSizeBytes = img.encodeJpg(fullSizeImage, quality: 85);
      
      // サムネイルを生成（200px四方）
      final img.Image thumbnailImage = _resizeImage(originalImage, 200);
      final Uint8List thumbnailBytes = img.encodeJpg(thumbnailImage, quality: 70);

      // Storageのパスを生成
      final String fullSizePath = 'images/messages/${user.uid}/${timestamp}_full.jpg';
      final String thumbnailPath = 'images/messages/${user.uid}/${timestamp}_thumb.jpg';

      // フルサイズ画像をアップロード
      final TaskSnapshot fullSizeSnapshot = await _storage
          .ref(fullSizePath)
          .putData(fullSizeBytes, SettableMetadata(contentType: 'image/jpeg'));
      
      // サムネイルをアップロード
      final TaskSnapshot thumbnailSnapshot = await _storage
          .ref(thumbnailPath)
          .putData(thumbnailBytes, SettableMetadata(contentType: 'image/jpeg'));

      // ダウンロードURLを取得
      final String fullSizeUrl = await fullSizeSnapshot.ref.getDownloadURL();
      final String thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();

      return {
        'imageUrl': fullSizeUrl,
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      // エラーログは本番環境では出力しない
      // debugPrint('画像のアップロードに失敗しました: $e');
      throw Exception('画像のアップロードに失敗しました: $e');
    }
  }

  // 画像をリサイズする（最大サイズを指定）
  static img.Image _resizeImage(img.Image image, int maxSize) {
    // 既に指定サイズ以下の場合はそのまま返す
    if (image.width <= maxSize && image.height <= maxSize) {
      return image;
    }

    // アスペクト比を保ちながらリサイズ
    int newWidth, newHeight;
    if (image.width > image.height) {
      newWidth = maxSize;
      newHeight = (image.height * maxSize / image.width).round();
    } else {
      newHeight = maxSize;
      newWidth = (image.width * maxSize / image.height).round();
    }

    return img.copyResize(image, width: newWidth, height: newHeight);
  }

  // アップロード進捗を監視しながら画像をアップロード
  static Future<Map<String, String>> uploadImageWithProgress(
    XFile imageFile,
    Function(double) onProgress,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('ユーザーがログインしていません');
    }

    try {
      // 画像データを読み込み
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // 画像をデコード
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('画像のデコードに失敗しました');
      }

      // タイムスタンプを生成
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // 画像を処理
      final img.Image fullSizeImage = _resizeImage(originalImage, 1920);
      final Uint8List fullSizeBytes = img.encodeJpg(fullSizeImage, quality: 85);
      
      final img.Image thumbnailImage = _resizeImage(originalImage, 200);
      final Uint8List thumbnailBytes = img.encodeJpg(thumbnailImage, quality: 70);

      // Storageのパス
      final String fullSizePath = 'images/messages/${user.uid}/${timestamp}_full.jpg';
      final String thumbnailPath = 'images/messages/${user.uid}/${timestamp}_thumb.jpg';

      // フルサイズ画像をアップロード（進捗付き）
      final UploadTask fullSizeTask = _storage
          .ref(fullSizePath)
          .putData(fullSizeBytes, SettableMetadata(contentType: 'image/jpeg'));
      
      // 進捗を監視
      fullSizeTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress * 0.8); // フルサイズは全体の80%として扱う
      });

      final TaskSnapshot fullSizeSnapshot = await fullSizeTask;

      // サムネイルをアップロード
      final UploadTask thumbnailTask = _storage
          .ref(thumbnailPath)
          .putData(thumbnailBytes, SettableMetadata(contentType: 'image/jpeg'));
      
      // サムネイルの進捗も監視
      thumbnailTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(0.8 + progress * 0.2); // サムネイルは残り20%
      });

      final TaskSnapshot thumbnailSnapshot = await thumbnailTask;

      // URLを取得
      final String fullSizeUrl = await fullSizeSnapshot.ref.getDownloadURL();
      final String thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();

      onProgress(1.0); // 完了

      return {
        'imageUrl': fullSizeUrl,
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      // エラーログは本番環境では出力しない
      // debugPrint('画像のアップロードに失敗しました: $e');
      throw Exception('画像のアップロードに失敗しました: $e');
    }
  }
}