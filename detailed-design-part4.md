## 6. エラー処理（続き）

### 6.1 エラーハンドリングの実装（続き）

```dart
// エラーハンドラー
class ErrorHandler {
  static void showErrorDialog(BuildContext context, AppError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  static Future<T> runWithErrorHandling<T>({
    required BuildContext context,
    required Future<T> Function() task,
    String? loadingMessage,
  }) async {
    try {
      if (loadingMessage != null) {
        // ローディング表示
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(loadingMessage),
              ],
            ),
          ),
        );
      }
      
      final result = await task();
      
      if (loadingMessage != null) {
        // ローディング非表示
        Navigator.pop(context);
      }
      
      return result;
    } catch (e) {
      if (loadingMessage != null) {
        // ローディング非表示
        Navigator.pop(context);
      }
      
      // エラー変換
      final AppError appError = e is AppError
          ? e
          : AppError(
              message: 'エラーが発生しました: ${e.toString()}',
              code: 'UNKNOWN',
              originalError: e,
            );
      
      // エラーダイアログ表示
      showErrorDialog(context, appError);
      
      // 再スロー
      throw appError;
    }
  }
  
  // 権限確認
  static Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }
    
    final result = await Permission.camera.request();
    return result.isGranted;
  }
  
  static Future<bool> checkStoragePermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted) {
        return true;
      }
      
      final result = await Permission.photos.request();
      return result.isGranted;
    } else {
      // Android
      final status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }
      
      final result = await Permission.storage.request();
      return result.isGranted;
    }
  }
}
```

## 7. アプリケーション初期化と設定

### 7.1 アプリケーションのエントリポイント

アプリケーションのエントリポイントとプロバイダー設定を実装します。

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // カメラの初期化
  final cameras = await availableCameras();
  
  // 権限の事前確認
  await Permission.camera.request();
  if (Platform.isAndroid) {
    await Permission.storage.request();
  } else {
    await Permission.photos.request();
  }
  
  runApp(
    ProviderScope(
      overrides: [
        availableCamerasProvider.overrideWithValue(cameras),
      ],
      child: const MyApp(),
    ),
  );
}

final availableCamerasProvider = Provider<List<CameraDescription>>((ref) {
  throw UnimplementedError('Should be overridden in main');
});

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '写真アプリ',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
    );
  }
}
```

### 7.2 アプリケーション設定

アプリケーションの設定を管理するためのクラスを実装します。

```dart
class AppSettings {
  // 設定の保存先
  static const String _prefsKey = 'app_settings';
  
  // デフォルト設定
  static const Map<String, dynamic> _defaults = {
    'cameraPreviewQuality': 'high',
    'saveToGallery': true,
    'maxOverlays': 10,
    'transparentPngQuality': 90,
  };
  
  // 設定の読み込み
  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_prefsKey);
    
    if (jsonString == null) {
      return Map<String, dynamic>.from(_defaults);
    }
    
    try {
      final Map<String, dynamic> settings = jsonDecode(jsonString);
      // デフォルト値とマージ
      return Map<String, dynamic>.from(_defaults)..addAll(settings);
    } catch (e) {
      return Map<String, dynamic>.from(_defaults);
    }
  }
  
  // 設定の保存
  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings);
    await prefs.setString(_prefsKey, jsonString);
  }
  
  // 個別の設定値を取得
  static Future<T> getSetting<T>(String key) async {
    final settings = await getSettings();
    return settings[key] as T;
  }
  
  // 個別の設定値を保存
  static Future<void> setSetting<T>(String key, T value) async {
    final settings = await getSettings();
    settings[key] = value;
    await saveSettings(settings);
  }
  
  // カメラプレビュー品質の変換
  static ResolutionPreset getCameraPresetFromSetting(String quality) {
    switch (quality) {
      case 'max':
        return ResolutionPreset.max;
      case 'ultraHigh':
        return ResolutionPreset.ultraHigh;
      case 'veryHigh':
        return ResolutionPreset.veryHigh;
      case 'high':
        return ResolutionPreset.high;
      case 'medium':
        return ResolutionPreset.medium;
      case 'low':
        return ResolutionPreset.low;
      default:
        return ResolutionPreset.high;
    }
  }
}
```

## 8. デバイスとプラットフォーム対応

### 8.1 プラットフォーム固有の実装

Android と iOS の違いに対応するためのユーティリティを実装します。

```dart
class PlatformUtils {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  
  // ファイルパスをプラットフォームに合わせて調整
  static String normalizePath(String path) {
    if (isIOS && path.startsWith('file://')) {
      return path;
    } else if (isAndroid && !path.startsWith('file://')) {
      return 'file://$path';
    }
    return path;
  }
  
  // ギャラリーへの保存方法をプラットフォームに合わせて実装
  static Future<String?> saveToGallery(Uint8List bytes, {
    required String name,
    required String fileType,
  }) async {
    try {
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: name,
      );
      
      if (isAndroid) {
        return result['filePath'];
      } else {
        // iOSの場合はpathが返される
        return result;
      }
    } catch (e) {
      print('Gallery save error: $e');
      return null;
    }
  }
  
  // メディアスキャンをリクエスト（Android専用）
  static Future<void> scanFile(String path) async {
    if (isAndroid) {
      try {
        await platform.invokeMethod('scanFile', {'path': path});
      } catch (e) {
        print('Media scan error: $e');
      }
    }
  }
  
  // プラットフォーム固有のメソッドチャネル
  static const platform = MethodChannel('com.example.photo_app/platform');
}
```

### 8.2 レスポンシブデザインと画面サイズ対応

異なる画面サイズに対応するためのレスポンシブデザインを実装します。

```dart
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  
  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    this.tablet,
  }) : super(key: key);
  
  // デバイスの種類を判定
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;
      
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 650;
  
  @override
  Widget build(BuildContext context) {
    if (isTablet(context) && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

// 画面サイズに依存する値を提供
class SizeConfig {
  static MediaQueryData? _mediaQueryData;
  static double? screenWidth;
  static double? screenHeight;
  static double? defaultSize;
  static Orientation? orientation;
  
  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData!.size.width;
    screenHeight = _mediaQueryData!.size.height;
    orientation = _mediaQueryData!.orientation;
    
    // デフォルトのサイズ（画面の幅の10分の1）
    defaultSize = orientation == Orientation.landscape
        ? screenHeight! * 0.024
        : screenWidth! * 0.024;
  }
  
  // 画面幅に対する比率でサイズを計算
  static double getProportionateScreenWidth(double inputWidth) {
    double screenWidth = SizeConfig.screenWidth!;
    // 375はデザイン時の画面幅
    return (inputWidth / 375.0) * screenWidth;
  }
  
  // 画面高さに対する比率でサイズを計算
  static double getProportionateScreenHeight(double inputHeight) {
    double screenHeight = SizeConfig.screenHeight!;
    // 812はデザイン時の画面高さ
    return (inputHeight / 812.0) * screenHeight;
  }
}
```

## 9. 依存関係と必要なパッケージ

アプリケーションの開発に必要なパッケージの一覧を示します。

```yaml
# pubspec.yaml

name: photo_app
description: A photo application with overlay and transparent PNG features

# バージョン
version: 1.0.0+1

environment:
  sdk: ">=2.17.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter
  
  # UI関連
  cupertino_icons: ^1.0.5
  flutter_svg: ^1.1.6
  
  # 状態管理
  flutter_riverpod: ^2.3.6
  
  # カメラ
  camera: ^0.10.5+2
  image_picker: ^0.8.7+5
  
  # 画像処理
  image: ^4.0.17
  path_provider: ^2.0.15
  image_gallery_saver: ^2.0.3
  uuid: ^3.0.7
  
  # ストレージと権限
  shared_preferences: ^2.1.1
  permission_handler: ^10.3.0
  
  # ユーティリティ
  equatable: ^2.0.5
  intl: ^0.18.1
  share_plus: ^7.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.1
  build_runner: ^2.4.5

flutter:
  uses-material-design: true
  
  assets:
    - assets/icons/
    - assets/images/
```

## 10. パフォーマンス要件対応

### 10.1 パフォーマンス最適化の具体的実装

要件に記載されたパフォーマンス要件に対応する具体的な実装です。

```dart
class PerformanceOptimizer {
  // カメラプレビューの最適化（30fps以上）
  static CameraController optimizeCameraPreview(CameraDescription camera) {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    
    // フレームレート設定
    controller.setFpsRange(30, 60);
    
    return controller;
  }
  
  // オーバーレイ操作のパフォーマンス最適化（100ms以内のレスポンス）
  static Widget optimizeOverlayOperation(Widget overlayWidget) {
    return RepaintBoundary(
      child: overlayWidget,
    );
  }
  
  // 透過PNG作成処理の最適化（5秒以内の処理完了）
  static Future<void> optimizeTransparentPngCreation(Function() processingTask) async {
    // 処理前にキャッシュクリア
    imageCache.clear();
    imageCache.clearLiveImages();
    
    // 他の重いタスクを一時停止
    final isolate = await Isolate.spawn(
      _isolateProcessing,
      processingTask,
    );
    
    // 5秒のタイムアウト設定
    Timer(const Duration(seconds: 5), () {
      isolate.kill(priority: Isolate.immediate);
      throw TimeoutException('PNG処理がタイムアウトしました');
    });
  }
  
  static void _isolateProcessing(Function() task) {
    task();
  }
  
  // ギャラリー表示の最適化（100枚以上のスムーズスクロール）
  static ScrollController optimizeGalleryScroll() {
    final controller = ScrollController();
    
    // スクロール中は低品質のサムネイルを表示
    controller.addListener(() {
      if (controller.position.isScrollingNotifier.value) {
        // スクロール中は低品質表示
        ImageUtils.setLowQualityMode(true);
      } else {
        // スクロール停止後に高品質表示に戻す
        Future.delayed(const Duration(milliseconds: 200), () {
          ImageUtils.setLowQualityMode(false);
        });
      }
    });
    
    return controller;
  }
}

// ImageUtilsの拡張
extension on ImageUtils {
  static bool _lowQualityMode = false;
  
  static void setLowQualityMode(bool isLowQuality) {
    _lowQualityMode = isLowQuality;
  }
  
  static int getThumbnailSize() {
    return _lowQualityMode ? 100 : 300;
  }
}
```

## 11. セキュリティ対応

### 11.1 権限管理とデータ保護

セキュリティ要件に対応するための実装です。

```dart
class SecurityManager {
  // 権限チェック
  static Future<bool> checkAllRequiredPermissions() async {
    final permissionsToCheck = <Permission>[];
    
    // カメラ権限
    permissionsToCheck.add(Permission.camera);
    
    // ストレージ権限（プラットフォームによって異なる）
    if (Platform.isAndroid) {
      permissionsToCheck.add(Permission.storage);
    } else if (Platform.isIOS) {
      permissionsToCheck.add(Permission.photos);
    }
    
    // すべての権限をチェック
    Map<Permission, PermissionStatus> statuses = await permissionsToCheck.request();
    
    // すべての権限が許可されているかをチェック
    return statuses.values.every((status) => status.isGranted);
  }
  
  // 権限リクエスト
  static Future<bool> requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    }
    
    final status = await permission.request();
    return status.isGranted;
  }
  
  // アプリ起動時の権限チェック
  static Future<void> checkPermissionsOnStartup(BuildContext context) async {
    final hasAllPermissions = await checkAllRequiredPermissions();
    
    if (!hasAllPermissions) {
      // 権限がない場合、ダイアログを表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('権限が必要です'),
          content: const Text(
            'このアプリはカメラとフォトライブラリへのアクセス権限が必要です。'
            '設定から権限を許可してください。'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('設定を開く'),
            ),
          ],
        ),
      );
    }
  }
  
  // データ保護
  static Future<Directory> getSecureDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final secureDir = Directory('${directory.path}/secure_data');
    
    if (!await secureDir.exists()) {
      await secureDir.create(recursive: true);
    }
    
    // .nomediaファイルを作成してメディアスキャンから除外（Androidのみ）
    if (Platform.isAndroid) {
      final nomediaFile = File('${secureDir.path}/.nomedia');
      if (!await nomediaFile.exists()) {
        await nomediaFile.create();
      }
    }
    
    return secureDir;
  }
}
```