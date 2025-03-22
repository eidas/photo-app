## 5. パフォーマンス最適化

### 5.1 画像処理の最適化

画像処理のパフォーマンスを向上させるためのユーティリティクラスを実装します。

```dart
class ImageUtils {
  // イメージをキャッシュに保存するためのLRUキャッシュ
  static final LruCache<String, Uint8List> _imageCache = LruCache<String, Uint8List>(size: 20);
  
  // リサイズされた画像をキャッシュから取得
  static Future<Uint8List> getResizedImage(String path, int width, int height) async {
    final cacheKey = '$path-$width-$height';
    
    // キャッシュにあればそれを返す
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache.get(cacheKey)!;
    }
    
    // なければファイルから読み込んでリサイズ
    final file = File(path);
    final bytes = await file.readAsBytes();
    
    final img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }
    
    final img.Image resizedImage = img.copyResize(
      originalImage,
      width: width,
      height: height,
    );
    
    final Uint8List resizedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85));
    
    // キャッシュに保存
    _imageCache.put(cacheKey, resizedBytes);
    
    return resizedBytes;
  }
  
  // 透過PNGの処理を最適化
  static Future<Uint8List> optimizeTransparentPng(Uint8List pngData) async {
    final img.Image? image = img.decodeImage(pngData);
    if (image == null) {
      throw Exception('Failed to decode PNG');
    }
    
    // イメージのサイズが大きすぎる場合はリサイズ
    img.Image processedImage = image;
    final maxSize = 1500; // 最大サイズ
    
    if (image.width > maxSize || image.height > maxSize) {
      final double ratio = image.width / image.height;
      int newWidth, newHeight;
      
      if (ratio > 1) {
        // 幅が大きい場合
        newWidth = maxSize;
        newHeight = (maxSize / ratio).round();
      } else {
        // 高さが大きい場合
        newHeight = maxSize;
        newWidth = (maxSize * ratio).round();
      }
      
      processedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
      );
    }
    
    // PNGエンコードオプションを最適化
    final optimizedPngData = img.encodePng(
      processedImage,
      level: 6, // 圧縮レベル（0-9）
    );
    
    return Uint8List.fromList(optimizedPngData);
  }
}
```

### 5.2 メモリ使用量最適化

メモリ使用量を最適化するためのユーティリティクラスを実装します。

```dart
class MemoryOptimizer {
  // キャッシュをクリア
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
  
  // 大きな画像を処理する前にメモリを確保
  static Future<void> prepareForLargeImageProcessing() async {
    // ガベージコレクションを促す
    await Future.delayed(const Duration(milliseconds: 100));
    clearImageCache();
  }
  
  // ギャラリーのサムネイルをページングで読み込む
  static const int pageSizeForGallery = 20;
  
  static Future<List<Photo>> loadPhotosInPagination(
    List<Photo> allPhotos,
    int page,
    int pageSize,
  ) async {
    final startIndex = page * pageSize;
    final endIndex = min(startIndex + pageSize, allPhotos.length);
    
    if (startIndex >= allPhotos.length) {
      return [];
    }
    
    return allPhotos.sublist(startIndex, endIndex);
  }
}
```

## 6. エラー処理

### 6.1 エラーハンドリングの実装

アプリケーション全体でのエラーハンドリングを実装します。

```dart
class AppError extends Error {
  final String message;
  final String code;
  final dynamic originalError;
  
  AppError({
    required this.message,
    required this.code,
    this.originalError,
  });
  
  @override
  String toString() => 'AppError: $code - $message';
}

// カメラエラー
class CameraError extends AppError {
  CameraError({
    required String message,
    required String code,
    dynamic originalError,
  }) : super(
         message: message,
         code: 'CAMERA_$code',
         originalError: originalError,
       );
  
  factory CameraError.accessDenied() {
    return CameraError(
      message: 'カメラへのアクセスが許可されていません。設定から許可してください。',
      code: 'ACCESS_DENIED',
    );
  }
  
  factory CameraError.notAvailable() {
    return CameraError(
      message: 'カメラが利用できません。',
      code: 'NOT_AVAILABLE',
    );
  }
}

// ストレージエラー
class StorageError extends AppError {
  StorageError({
    required String message,
    required String code,
    dynamic originalError,
  }) : super(
         message: message,
         code: 'STORAGE_$code',
         originalError: originalError,
       );
  
  factory StorageError.accessDenied() {
    return StorageError(
      message: 'ストレージへのアクセスが許可されていません。設定から許可してください。',
      code: 'ACCESS_DENIED',
    );
  }
  
  factory StorageError.insufficientSpace() {
    return StorageError(
      message: 'ストレージの空き容量が不足しています。',
      code: 'INSUFFICIENT_SPACE',
    );
  }
}

// 画像処理エラー
class ImageProcessingError extends AppError {
  ImageProcessingError({
    required String message,
    required String code,
    dynamic originalError,
  }) : super(
         message: message,
         code: 'IMAGE_PROCESSING_$code',
         originalError: originalError,
       );
  
  factory ImageProcessingError.tooLargeImage() {
    return ImageProcessingError(
      message: '画像サイズが大きすぎます。より小さい画像を選択してください。',
      code: 'TOO_LARGE',
    );
  }
  
  factory ImageProcessingError.processingFailed() {
    return ImageProcessingError(
      message: '画像処理に失敗しました。別の画像で試してください。',
      code: 'PROCESSING_FAILED',
    );
  }
}
```