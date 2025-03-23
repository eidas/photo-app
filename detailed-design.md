# 写真アプリシステム詳細設計書

## 技術スタック選択の検討

### Web技術(React) + PWA
**メリット**:
- Webプラットフォームの広い互換性
- フロントエンド開発者が多く、リソース確保が容易
- 既存のWeb APIとの統合が容易
- カメラAPIやファイルシステムAPIなどのブラウザAPIが成熟している
- PWAによりデスクトップを含む複数プラットフォームへの展開が容易

**デメリット**:
- ネイティブアプリと比較すると一部のデバイス機能へのアクセスが制限される場合がある
- パフォーマンスがネイティブアプリに劣る可能性がある
- PWAのサポート状況が特にiOSで不完全な場合がある

### Flutter
**メリット**:
- 単一コードベースでのネイティブパフォーマンス
- ネイティブのUIコンポーネントへの直接アクセス
- 画像処理やカメラなどのハードウェア機能への優れたアクセス
- 優れたパフォーマンスと滑らかなアニメーション
- ホットリロードによる迅速な開発サイクル

**デメリット**:
- React開発者と比較するとFlutter/Dart開発者が少ない
- ウェブ展開時のパフォーマンスが劣る場合がある
- 一部のサードパーティライブラリが成熟していない

### 選択: Flutter
本プロジェクトでは**Flutter**を採用します。この選択の主な理由は：

1. 画像処理とカメラ操作が中心機能であり、ネイティブのハードウェアアクセスが重要
2. オーバーレイ操作やリアルタイム画像処理において優れたパフォーマンスが求められる
3. カスタムUI操作（ドラッグ、ピンチズーム、回転）の実装がFlutterで洗練されている
4. ネイティブに近いアプリ体験をiOSとAndroidの両方で提供できる

パフォーマンス要件として「カメラプレビューは最低30fps以上」「オーバーレイ画像操作のレスポンスは100ms以内」が指定されており、これらの要件を満たすにはFlutterがより適しています。また画像処理操作が多いため、Flutterのハードウェアアクセラレーションを活用します。

## 1. システム構成

### 1.1 アプリケーションアーキテクチャ
本アプリケーションはFlutterを使用した**クリーンアーキテクチャ**パターンを採用します。

#### レイヤー構成
1. **プレゼンテーション層**
   - UI/UXコンポーネント (Widgets)
   - 画面遷移管理 (Navigation)
   - 状態管理 (State Management)

2. **ドメイン層**
   - ビジネスロジック
   - エンティティモデル
   - ユースケース

3. **データ層**
   - リポジトリ実装
   - データソース (ローカルストレージ)
   - 外部サービス (カメラ、ギャラリーなど)

### 1.2 状態管理
プロジェクトの状態管理には**Riverpod**を採用します。Riverpodは依存性の注入とリアクティブな状態管理を可能にします。

### 1.3 ディレクトリ構造
```
lib/
├── main.dart                 # アプリケーションのエントリーポイント
├── app/                      # アプリケーション全体の設定
│   ├── app.dart              # MaterialAppの設定
│   └── routes.dart           # ルート定義
├── core/                     # コア機能
│   ├── error/                # エラー処理
│   ├── utils/                # ユーティリティ関数
│   └── constants/            # 定数定義
├── domain/                   # ドメイン層
│   ├── entities/             # エンティティモデル
│   │   ├── photo.dart
│   │   ├── overlay_image.dart
│   │   └── transparent_png.dart
│   ├── repositories/         # リポジトリインターフェース
│   │   ├── photo_repository.dart
│   │   └── storage_repository.dart
│   └── usecases/             # ユースケース
│       ├── take_photo.dart
│       ├── create_transparent_png.dart
│       └── manage_overlay.dart
├── data/                     # データ層
│   ├── repositories/         # リポジトリ実装
│   │   ├── photo_repository_impl.dart
│   │   └── storage_repository_impl.dart
│   ├── datasources/          # データソース
│   │   ├── camera_data_source.dart
│   │   ├── gallery_data_source.dart
│   │   └── local_storage_data_source.dart
│   └── models/               # データモデル
│       ├── photo_model.dart
│       ├── overlay_model.dart
│       └── metadata_model.dart
└── presentation/            # プレゼンテーション層
    ├── providers/           # Riverpodプロバイダー
    │   ├── camera_provider.dart
    │   ├── overlay_provider.dart
    │   └── gallery_provider.dart
    ├── screens/             # 画面
    │   ├── main_screen.dart
    │   ├── camera_screen.dart
    │   ├── overlay_screen.dart
    │   ├── transparent_png_screen.dart
    │   └── gallery_screen.dart
    ├── widgets/             # 再利用可能なウィジェット
    │   ├── camera/
    │   ├── overlay/
    │   ├── transparent_png/
    │   └── gallery/
    └── controllers/         # 画面コントローラー
        ├── camera_controller.dart
        ├── overlay_controller.dart
        └── transparent_png_controller.dart
```

## 2. 詳細機能設計

### 2.1 カメラ機能

#### 2.1.1 カメラモジュール
カメラ機能には`camera`パッケージを採用します。

```dart
// CameraDataSource抽象クラス
abstract class CameraDataSource {
  Future<void> initialize();
  Stream<CameraImage> getPreviewStream();
  Future<Uint8List> capturePhoto();
  Future<void> dispose();
}

// CameraDataSourceの実装
class CameraDataSourceImpl implements CameraDataSource {
  late CameraController _cameraController;
  final CameraDescription _camera;
  
  CameraDataSourceImpl(this._camera);
  
  @override
  Future<void> initialize() async {
    _cameraController = CameraController(
      _camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController.initialize();
  }
  
  @override
  Stream<CameraImage> getPreviewStream() {
    return _cameraController.startImageStream();
  }
  
  @override
  Future<Uint8List> capturePhoto() async {
    final XFile file = await _cameraController.takePicture();
    return await file.readAsBytes();
  }
  
  @override
  Future<void> dispose() async {
    await _cameraController.dispose();
  }
}
```

#### 2.1.2 カメラプレビュー実装
カメラプレビューは画面全体に表示し、30fps以上のフレームレートを確保します。

```dart
class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;
  
  const CameraPreviewWidget({Key? key, required this.controller}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width * controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
```

#### 2.1.3 写真撮影実装
写真をJPEG形式でデバイスのギャラリーに保存する機能を実装します。

```dart
class PhotoRepository {
  final CameraDataSource cameraDataSource;
  final StorageRepository storageRepository;
  
  PhotoRepository(this.cameraDataSource, this.storageRepository);
  
  Future<Photo> takePhoto() async {
    final photoData = await cameraDataSource.capturePhoto();
    
    // 写真のメタデータを作成
    final metadata = PhotoMetadata(
      createdAt: DateTime.now(),
      type: PhotoType.normal,
    );
    
    // 写真をデバイスに保存
    final savedPhotoPath = await storageRepository.savePhoto(
      photoData, 
      metadata,
      saveToGallery: true
    );
    
    return Photo(
      id: const Uuid().v4(),
      path: savedPhotoPath,
      metadata: metadata,
    );
  }
}
```

### 2.2 オーバーレイ撮影機能

#### 2.2.1 オーバーレイ画像管理
オーバーレイ画像の読み込みと管理を行います。

```dart
class OverlayImage {
  final String id;
  final String path;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final Size originalSize;
  
  OverlayImage({
    required this.id,
    required this.path,
    this.x = 0.0,
    this.y = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
    required this.originalSize,
  });
  
  OverlayImage copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return OverlayImage(
      id: id,
      path: path,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      originalSize: originalSize,
    );
  }
}

class OverlayManager {
  final List<OverlayImage> _overlays = [];
  
  List<OverlayImage> get overlays => List.unmodifiable(_overlays);
  
  void addOverlay(OverlayImage overlay) {
    if (_overlays.length < 10) {
      _overlays.add(overlay);
    }
  }
  
  void removeOverlay(String id) {
    _overlays.removeWhere((overlay) => overlay.id == id);
  }
  
  void updateOverlay(String id, {double? x, double? y, double? scale, double? rotation}) {
    final index = _overlays.indexWhere((overlay) => overlay.id == id);
    if (index != -1) {
      _overlays[index] = _overlays[index].copyWith(
        x: x,
        y: y,
        scale: scale,
        rotation: rotation,
      );
    }
  }
  
  void clearOverlays() {
    _overlays.clear();
  }
}
```

#### 2.2.2 オーバーレイ操作UIの実装
タッチジェスチャーを使用したオーバーレイ画像の操作UI実装です。

```dart
class OverlayImageWidget extends StatefulWidget {
  final OverlayImage overlay;
  final Function(OverlayImage) onUpdate;
  
  const OverlayImageWidget({
    Key? key,
    required this.overlay,
    required this.onUpdate,
  }) : super(key: key);
  
  @override
  State<OverlayImageWidget> createState() => _OverlayImageWidgetState();
}

class _OverlayImageWidgetState extends State<OverlayImageWidget> {
  late OverlayImage _overlay;
  
  @override
  void initState() {
    super.initState();
    _overlay = widget.overlay;
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _overlay.x,
      top: _overlay.y,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Transform.rotate(
          angle: _overlay.rotation,
          child: Transform.scale(
            scale: _overlay.scale,
            child: Image.file(
              File(_overlay.path),
              width: _overlay.originalSize.width,
              height: _overlay.originalSize.height,
            ),
          ),
        ),
      ),
    );
  }
  
  Offset? _startOffset;
  double? _startScale;
  double? _startRotation;
  
  void _onScaleStart(ScaleStartDetails details) {
    _startOffset = Offset(_overlay.x, _overlay.y);
    _startScale = _overlay.scale;
    _startRotation = _overlay.rotation;
  }
  
  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.pointerCount == 1) {
        // 移動操作
        _overlay = _overlay.copyWith(
          x: _startOffset!.dx + details.focalPointDelta.dx,
          y: _startOffset!.dy + details.focalPointDelta.dy,
        );
      } else if (details.pointerCount >= 2) {
        // 拡大縮小と回転
        _overlay = _overlay.copyWith(
          scale: (_startScale! * details.scale).clamp(0.1, 3.0),
          rotation: _startRotation! + details.rotation,
        );
      }
    });
  }
  
  void _onScaleEnd(ScaleEndDetails details) {
    widget.onUpdate(_overlay);
  }
}
```

#### 2.2.3 合成写真撮影機能
カメラプレビューとオーバーレイを合成して撮影する機能を実装します。

```dart
class OverlayPhotoRepository {
  final CameraDataSource cameraDataSource;
  final StorageRepository storageRepository;
  final OverlayManager overlayManager;
  
  OverlayPhotoRepository(
    this.cameraDataSource,
    this.storageRepository,
    this.overlayManager,
  );
  
  Future<Photo> takeOverlayPhoto(Size viewSize) async {
    // カメラで写真を撮影
    final photoData = await cameraDataSource.capturePhoto();
    
    // UIキャンバスから合成画像を作成
    final ui.Image capturedImage = await decodeImageFromList(photoData);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // カメラ画像を描画
    final photoRect = Rect.fromLTWH(0, 0, viewSize.width, viewSize.height);
    canvas.drawImageRect(
      capturedImage,
      Rect.fromLTWH(0, 0, capturedImage.width.toDouble(), capturedImage.height.toDouble()),
      photoRect,
      Paint(),
    );
    
    // オーバーレイを描画
    for (final overlay in overlayManager.overlays) {
      final overlayImage = await _loadOverlayImage(overlay.path);
      final overlayRect = Rect.fromLTWH(
        overlay.x,
        overlay.y,
        overlay.originalSize.width * overlay.scale,
        overlay.originalSize.height * overlay.scale,
      );
      
      canvas.save();
      canvas.translate(overlay.x + (overlayRect.width / 2), overlay.y + (overlayRect.height / 2));
      canvas.rotate(overlay.rotation);
      canvas.translate(-(overlay.x + (overlayRect.width / 2)), -(overlay.y + (overlayRect.height / 2)));
      
      canvas.drawImageRect(
        overlayImage,
        Rect.fromLTWH(0, 0, overlayImage.width.toDouble(), overlayImage.height.toDouble()),
        overlayRect,
        Paint(),
      );
      
      canvas.restore();
    }
    
    final ui.Image compositeImage = await recorder.endRecording().toImage(
      viewSize.width.toInt(),
      viewSize.height.toInt(),
    );
    
    final ByteData? byteData = await compositeImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List compositeData = byteData!.buffer.asUint8List();
    
    // JPEGに変換
    final Uint8List jpegData = await _convertToJpeg(compositeData);
    
    // オーバーレイのメタデータを記録
    final overlayInfoList = overlayManager.overlays.map((overlay) => {
      'id': overlay.id,
      'path': overlay.path,
      'x': overlay.x,
      'y': overlay.y,
      'scale': overlay.scale,
      'rotation': overlay.rotation,
    }).toList();
    
    // 写真のメタデータを作成
    final metadata = PhotoMetadata(
      createdAt: DateTime.now(),
      type: PhotoType.overlay,
      overlayInfo: overlayInfoList,
    );
    
    // 写真をデバイスに保存
    final savedPhotoPath = await storageRepository.savePhoto(
      jpegData, 
      metadata,
      saveToGallery: true
    );
    
    return Photo(
      id: const Uuid().v4(),
      path: savedPhotoPath,
      metadata: metadata,
    );
  }
  
  Future<ui.Image> _loadOverlayImage(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return await decodeImageFromList(bytes);
  }
  
  Future<Uint8List> _convertToJpeg(Uint8List pngData) async {
    final img.Image? image = img.decodeImage(pngData);
    return Uint8List.fromList(img.encodeJpg(image!, quality: 90));
  }
}
```

### 2.3 透過PNG作成機能

#### 2.3.1 画像選択機能
デバイスのギャラリーから画像を選択する機能を実装します。

```dart
class ImagePickerService {
  Future<File?> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }
}
```

#### 2.3.2 透過PNG生成処理
2枚の画像から透過PNGを生成する処理を実装します。

```dart
class TransparentPngCreator {
  // 差分検出のしきい値
  final int _threshold = 30;
  
  Future<Uint8List> createTransparentPng(File image1, File image2) async {
    // 画像をデコード
    final bytes1 = await image1.readAsBytes();
    final bytes2 = await image2.readAsBytes();
    
    final img.Image? img1 = img.decodeImage(bytes1);
    final img.Image? img2 = img.decodeImage(bytes2);
    
    if (img1 == null || img2 == null) {
      throw Exception('Failed to decode images');
    }
    
    // 画像サイズが異なる場合はリサイズ
    img.Image processedImg1 = img1;
    img.Image processedImg2 = img2;
    
    if (img1.width != img2.width || img1.height != img2.height) {
      // 小さい方のサイズに合わせる
      final width = min(img1.width, img2.width);
      final height = min(img1.height, img2.height);
      
      processedImg1 = img.copyResize(img1, width: width, height: height);
      processedImg2 = img.copyResize(img2, width: width, height: height);
    }
    
    // 透過PNG作成
    final resultImage = img.Image(
      width: processedImg1.width,
      height: processedImg1.height,
      numChannels: 4,
    );
    
    // 各ピクセルの差分を計算して透明度を設定
    for (int y = 0; y < resultImage.height; y++) {
      for (int x = 0; x < resultImage.width; x++) {
        final pixel1 = processedImg1.getPixel(x, y);
        final pixel2 = processedImg2.getPixel(x, y);
        
        final r1 = img.getRed(pixel1);
        final g1 = img.getGreen(pixel1);
        final b1 = img.getBlue(pixel1);
        
        final r2 = img.getRed(pixel2);
        final g2 = img.getGreen(pixel2);
        final b2 = img.getBlue(pixel2);
        
        // 色の差分を計算
        final diffR = (r1 - r2).abs();
        final diffG = (g1 - g2).abs();
        final diffB = (b1 - b2).abs();
        
        // 差分の平均値
        final avgDiff = (diffR + diffG + diffB) / 3;
        
        // 差分が閾値を超える場合は不透明、それ以外は透明に
        int alpha = 0;
        if (avgDiff > _threshold) {
          alpha = 255; // 不透明
          
          // 画像1のピクセル色を使用
          resultImage.setPixel(x, y, img.getColor(r1, g1, b1, alpha));
        } else {
          // 透明なピクセル
          resultImage.setPixel(x, y, img.getColor(0, 0, 0, alpha));
        }
      }
    }
    
    // ノイズ除去フィルタを適用
    final filteredImage = _applyNoiseFilter(resultImage);
    
    // 自動トリミング
    final trimmedImage = _autoTrim(filteredImage);
    
    // PNGとしてエンコード
    final pngData = img.encodePng(trimmedImage);
    return Uint8List.fromList(pngData);
  }
  
  // ノイズ除去フィルタ
  img.Image _applyNoiseFilter(img.Image image) {
    // 孤立したピクセルを除去する簡易メディアンフィルタ
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 4,
    );
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = image.getPixel(x, y);
        final centerAlpha = img.getAlpha(center);
        
        // 周囲8ピクセルのアルファ値を取得
        int alphaSum = 0;
        int alphaCount = 0;
        
        for (int ny = -1; ny <= 1; ny++) {
          for (int nx = -1; nx <= 1; nx++) {
            if (nx == 0 && ny == 0) continue;
            
            final neighborAlpha = img.getAlpha(image.getPixel(x + nx, y + ny));
            alphaSum += neighborAlpha;
            alphaCount++;
          }
        }
        
        final avgAlpha = alphaSum / alphaCount;
        
        // 孤立ピクセル判定（中央が不透明で周囲のほとんどが透明、またはその逆）
        if ((centerAlpha > 200 && avgAlpha < 50) || (centerAlpha < 50 && avgAlpha > 200)) {
          // 周囲の多数決に従う
          final newAlpha = avgAlpha > 127 ? 255 : 0;
          result.setPixel(x, y, img.getColor(
            img.getRed(center),
            img.getGreen(center),
            img.getBlue(center),
            newAlpha,
          ));
        } else {
          result.setPixel(x, y, center);
        }
      }
    }
    
    return result;
  }
  
  // 自動トリミング
  img.Image _autoTrim(img.Image image) {
    // 不透明ピクセルの範囲を見つける
    int minX = image.width;
    int minY = image.height;
    int maxX = 0;
    int maxY = 0;
    
    bool hasOpaque = false;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final alpha = img.getAlpha(image.getPixel(x, y));
        if (alpha > 0) {
          hasOpaque = true;
          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }
    
    // 不透明ピクセルがない場合は元の画像を返す
    if (!hasOpaque) {
      return image;
    }
    
    // 余白を追加（10ピクセル）
    final padding = 10;
    minX = max(0, minX - padding);
    minY = max(0, minY - padding);
    maxX = min(image.width - 1, maxX + padding);
    maxY = min(image.height - 1, maxY + padding);
    
    // 指定された範囲を切り出す
    final width = maxX - minX + 1;
    final height = maxY - minY + 1;
    
    return img.copyCrop(image, x: minX, y: minY, width: width, height: height);
  }
}
```

#### 2.3.3 透過PNG保存機能
生成した透過PNGを保存し、オーバーレイリストに追加する機能を実装します。

```dart
class TransparentPngRepository {
  final StorageRepository storageRepository;
  final OverlayManager overlayManager;
  
  TransparentPngRepository(this.storageRepository, this.overlayManager);
  
  Future<String> saveTransparentPng(Uint8List pngData) async {
    // メタデータ作成
    final metadata = PhotoMetadata(
      createdAt: DateTime.now(),
      type: PhotoType.transparentPng,
    );
    
    // デバイスに保存
    final savedPath = await storageRepository.saveTransparentPng(
      pngData,
      metadata,
      saveToGallery: true,
    );
    
    // 画像サイズを取得
    final decodedImage = await decodeImageFromList(pngData);
    
    // オーバーレイマネージャーに追加
    overlayManager.addOverlay(OverlayImage(
      id: const Uuid().v4(),
      path: savedPath,
      originalSize: Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()),
    ));
    
    return savedPath;
  }
}
```