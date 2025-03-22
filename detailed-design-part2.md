## 続き: ギャラリー機能

#### 2.4.1 写真管理リポジトリ（続き）
```dart
  // 写真の種類でフィルタリング
  Future<List<Photo>> getPhotosByType(PhotoType type) async {
    final allPhotos = await getAllPhotos();
    return allPhotos.where((photo) => photo.metadata.type == type).toList();
  }
  
  // 写真を削除
  Future<void> deletePhoto(String photoId) async {
    await storageRepository.deletePhoto(photoId);
  }
  
  // 写真を共有
  Future<void> sharePhoto(String photoPath) async {
    final file = File(photoPath);
    if (await file.exists()) {
      await Share.shareFiles([photoPath]);
    }
  }
}
```

#### 2.4.2 ギャラリー画面の実装
写真一覧表示とフィルタリング機能を実装します。

```dart
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);
  
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PhotoType _selectedType = PhotoType.all;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }
  
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedType = PhotoType.all;
            break;
          case 1:
            _selectedType = PhotoType.normal;
            break;
          case 2:
            _selectedType = PhotoType.overlay;
            break;
          case 3:
            _selectedType = PhotoType.transparentPng;
            break;
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ギャラリー'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'すべて'),
            Tab(text: '通常写真'),
            Tab(text: 'オーバーレイ'),
            Tab(text: '透過PNG'),
          ],
        ),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final galleryState = ref.watch(galleryProvider(_selectedType));
          
          return galleryState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('エラー: $error')),
            data: (photos) => GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return GestureDetector(
                  onTap: () => _showPhotoDetail(context, photo),
                  child: PhotoThumbnail(photo: photo),
                );
              },
            ),
          );
        },
      ),
    );
  }
  
  void _showPhotoDetail(BuildContext context, Photo photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoDetailScreen(photo: photo),
      ),
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// サムネイル表示用ウィジェット
class PhotoThumbnail extends StatelessWidget {
  final Photo photo;
  
  const PhotoThumbnail({Key? key, required this.photo}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 透過PNG用の背景をチェック柄で表示
    final bool isTransparent = photo.metadata.type == PhotoType.transparentPng;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isTransparent)
            CustomPaint(painter: CheckerboardPainter()),
          Image.file(
            File(photo.path),
            fit: BoxFit.cover,
          ),
          Positioned(
            right: 4.0,
            bottom: 4.0,
            child: Icon(
              _getIconForPhotoType(photo.metadata.type),
              size: 16.0,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getIconForPhotoType(PhotoType type) {
    switch (type) {
      case PhotoType.normal:
        return Icons.photo;
      case PhotoType.overlay:
        return Icons.layers;
      case PhotoType.transparentPng:
        return Icons.image;
      default:
        return Icons.image;
    }
  }
}

// チェック柄の背景を描画するカスタムペインター
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 8.0;
    final paint = Paint()
      ..color = Colors.grey.shade300;
    
    for (int i = 0; i < size.width / cellSize; i++) {
      for (int j = 0; j < size.height / cellSize; j++) {
        if ((i + j) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(i * cellSize, j * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

#### 2.4.3 写真詳細画面と操作機能
写真の詳細表示と操作（削除、共有など）を実装します。

```dart
class PhotoDetailScreen extends StatelessWidget {
  final Photo photo;
  
  const PhotoDetailScreen({Key? key, required this.photo}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final bool isTransparent = photo.metadata.type == PhotoType.transparentPng;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPhotoTypeTitle(photo.metadata.type)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePhoto(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
          if (isTransparent)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              onPressed: () => _useAsOverlay(context),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: photo.id,
            child: Stack(
              children: [
                if (isTransparent)
                  CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: CheckerboardPainter(),
                  ),
                Image.file(
                  File(photo.path),
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _getPhotoTypeTitle(PhotoType type) {
    switch (type) {
      case PhotoType.normal:
        return '通常写真';
      case PhotoType.overlay:
        return 'オーバーレイ写真';
      case PhotoType.transparentPng:
        return '透過PNG';
      default:
        return '写真';
    }
  }
  
  Future<void> _sharePhoto(BuildContext context) async {
    final galleryRepo = Provider.of<GalleryRepository>(context, listen: false);
    await galleryRepo.sharePhoto(photo.path);
  }
  
  Future<void> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写真を削除'),
        content: const Text('この写真を削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final galleryRepo = Provider.of<GalleryRepository>(context, listen: false);
      await galleryRepo.deletePhoto(photo.id);
      Navigator.pop(context);
    }
  }
  
  void _useAsOverlay(BuildContext context) {
    if (photo.metadata.type == PhotoType.transparentPng) {
      final overlayManager = Provider.of<OverlayManager>(context, listen: false);
      
      // 画像サイズの取得（実際の実装ではイメージをデコードして取得）
      final file = File(photo.path);
      final Future<Size> getImageSize = () async {
        final bytes = await file.readAsBytes();
        final decodedImage = await decodeImageFromList(bytes);
        return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
      }();
      
      getImageSize.then((size) {
        overlayManager.addOverlay(OverlayImage(
          id: const Uuid().v4(),
          path: photo.path,
          originalSize: size,
        ));
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('オーバーレイとして設定しました')),
        );
        
        // オーバーレイ撮影画面に遷移
        Navigator.popUntil(context, (route) => route.isFirst);
        Provider.of<NavigationProvider>(context, listen: false).setIndex(1); // オーバーレイモードのインデックス
      });
    }
  }
}
```

## 3. データ管理設計

### 3.1 エンティティとモデル定義

#### 3.1.1 写真エンティティ

```dart
enum PhotoType {
  all,     // フィルタリング用
  normal,  // 通常写真
  overlay, // オーバーレイ写真
  transparentPng, // 透過PNG
}

class PhotoMetadata {
  final DateTime createdAt;
  final PhotoType type;
  final List<Map<String, dynamic>>? overlayInfo;
  
  PhotoMetadata({
    required this.createdAt,
    required this.type,
    this.overlayInfo,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'type': type.toString(),
      'overlayInfo': overlayInfo,
    };
  }
  
  factory PhotoMetadata.fromJson(Map<String, dynamic> json) {
    return PhotoMetadata(
      createdAt: DateTime.parse(json['createdAt']),
      type: PhotoType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PhotoType.normal,
      ),
      overlayInfo: json['overlayInfo'] != null
          ? List<Map<String, dynamic>>.from(json['overlayInfo'])
          : null,
    );
  }
}

class Photo {
  final String id;
  final String path;
  final PhotoMetadata metadata;
  
  Photo({
    required this.id,
    required this.path,
    required this.metadata,
  });
}
```

### 3.2 ストレージリポジトリの実装

アプリのデータを永続化するためのリポジトリを実装します。

```dart
class StorageRepositoryImpl implements StorageRepository {
  final String _appDirName = 'photo_app';
  final String _metadataFileName = 'metadata.json';
  
  Future<Directory> get _appDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final directory = Directory('${appDir.path}/$_appDirName');
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    return directory;
  }
  
  Future<File> get _metadataFile async {
    final dir = await _appDir;
    return File('${dir.path}/$_metadataFileName');
  }
  
  // メタデータをJSONとして保存
  Future<void> _saveMetadata(Map<String, dynamic> metadata) async {
    final file = await _metadataFile;
    final jsonString = jsonEncode(metadata);
    await file.writeAsString(jsonString);
  }
  
  // メタデータをJSONから読み込み
  Future<Map<String, dynamic>> _loadMetadata() async {
    final file = await _metadataFile;
    
    if (await file.exists()) {
      final jsonString = await file.readAsString();
      return jsonDecode(jsonString) as Map<String, dynamic>;
    }
    
    return {'photos': {}};
  }
  
  @override
  Future<String> savePhoto(
    Uint8List photoData,
    PhotoMetadata metadata, {
    bool saveToGallery = true,
  }) async {
    final dir = await _appDir;
    final photoId = const Uuid().v4();
    final photoPath = '${dir.path}/$photoId.jpg';
    
    // アプリ内ストレージに保存
    final file = File(photoPath);
    await file.writeAsBytes(photoData);
    
    // メタデータに写真情報を追加
    final allMetadata = await _loadMetadata();
    final photos = allMetadata['photos'] as Map<String, dynamic>? ?? {};
    
    photos[photoId] = {
      'path': photoPath,
      'metadata': metadata.toJson(),
    };
    
    allMetadata['photos'] = photos;
    await _saveMetadata(allMetadata);
    
    // デバイスのギャラリーにも保存（オプション）
    if (saveToGallery) {
      final result = await ImageGallerySaver.saveImage(
        photoData,
        quality: 90,
        name: 'PhotoApp_${metadata.type.toString()}_$photoId',
      );
    }
    
    return photoPath;
  }
  
  @override
  Future<String> saveTransparentPng(
    Uint8List pngData,
    PhotoMetadata metadata, {
    bool saveToGallery = true,
  }) async {
    final dir = await _appDir;
    final photoId = const Uuid().v4();
    final photoPath = '${dir.path}/$photoId.png';
    
    // アプリ内ストレージに保存
    final file = File(photoPath);
    await file.writeAsBytes(pngData);
    
    // メタデータに写真情報を追加
    final allMetadata = await _loadMetadata();
    final photos = allMetadata['photos'] as Map<String, dynamic>? ?? {};
    
    photos[photoId] = {
      'path': photoPath,
      'metadata': metadata.toJson(),
    };
    
    allMetadata['photos'] = photos;
    await _saveMetadata(allMetadata);
    
    // デバイスのギャラリーにも保存（オプション）
    if (saveToGallery) {
      final result = await ImageGallerySaver.saveImage(
        pngData,
        quality: 100,
        name: 'PhotoApp_TransparentPNG_$photoId',
      );
    }
    
    return photoPath;
  }
  
  @override
  Future<List<Photo>> getAllPhotos() async {
    final allMetadata = await _loadMetadata();
    final photos = allMetadata['photos'] as Map<String, dynamic>? ?? {};
    
    final List<Photo> result = [];
    
    for (final entry in photos.entries) {
      final id = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final path = data['path'] as String;
      final metadata = PhotoMetadata.fromJson(data['metadata']);
      
      // 確認：ファイルが実際に存在するか
      final file = File(path);
      if (await file.exists()) {
        result.add(Photo(
          id: id,
          path: path,
          metadata: metadata,
        ));
      }
    }
    
    // 日付の新しい順にソート
    result.sort((a, b) => b.metadata.createdAt.compareTo(a.metadata.createdAt));
    
    return result;
  }
  
  @override
  Future<void> deletePhoto(String photoId) async {
    final allMetadata = await _loadMetadata();
    final photos = allMetadata['photos'] as Map<String, dynamic>? ?? {};
    
    if (photos.containsKey(photoId)) {
      final photoData = photos[photoId] as Map<String, dynamic>;
      final path = photoData['path'] as String;
      
      // ファイル削除
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      
      // メタデータから削除
      photos.remove(photoId);
      allMetadata['photos'] = photos;
      await _saveMetadata(allMetadata);
    }
  }
}
```

## 4. 画面遷移と状態管理

### 4.1 ナビゲーション管理

アプリの画面遷移を管理するためのナビゲーションを実装します。

```dart
class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  
  int get selectedIndex => _selectedIndex;
  
  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _screens = [
    const CameraScreen(mode: CameraMode.normal),
    const CameraScreen(mode: CameraMode.overlay),
    const TransparentPngScreen(),
    const GalleryScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        return Scaffold(
          body: _screens[navProvider.selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: navProvider.selectedIndex,
            onTap: (index) => navProvider.setIndex(index),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt),
                label: '通常撮影',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.layers),
                label: 'オーバーレイ',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_fix_high),
                label: '透過PNG作成',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.photo_library),
                label: 'ギャラリー',
              ),
            ],
          ),
        );
      },
    );
  }
}
```

### 4.2 Riverpodプロバイダーの実装

状態管理にRiverpodを使用したプロバイダーを実装します。

```dart
// カメラプロバイダー
final cameraProvider = FutureProvider<CameraController>((ref) async {
  final cameras = await availableCameras();
  final camera = cameras.first;
  
  final controller = CameraController(
    camera,
    ResolutionPreset.high,
    enableAudio: false,
  );
  
  await controller.initialize();
  
  ref.onDispose(() {
    controller.dispose();
  });
  
  return controller;
});

// カメラモード
enum CameraMode {
  normal,
  overlay,
}

// 写真リポジトリプロバイダー
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final cameraDataSource = ref.watch(cameraDataSourceProvider);
  final storageRepository = ref.watch(storageRepositoryProvider);
  
  return PhotoRepository(cameraDataSource, storageRepository);
});

// オーバーレイ管理プロバイダー
final overlayManagerProvider = StateNotifierProvider<OverlayManagerNotifier, List<OverlayImage>>((ref) {
  return OverlayManagerNotifier();
});

class OverlayManagerNotifier extends StateNotifier<List<OverlayImage>> {
  OverlayManagerNotifier() : super([]);
  
  void addOverlay(OverlayImage overlay) {
    if (state.length < 10) {
      state = [...state, overlay];
    }
  }
  
  void removeOverlay(String id) {
    state = state.where((overlay) => overlay.id != id).toList();
  }
  
  void updateOverlay(String id, {double? x, double? y, double? scale, double? rotation}) {
    state = state.map((overlay) {
      if (overlay.id == id) {
        return overlay.copyWith(
          x: x,
          y: y,
          scale: scale,
          rotation: rotation,
        );
      }
      return overlay;
    }).toList();
  }
  
  void clearOverlays() {
    state = [];
  }
}

// ギャラリープロバイダー
final galleryProvider = FutureProvider.family<List<Photo>, PhotoType>((ref, type) async {
  final galleryRepository = ref.watch(galleryRepositoryProvider);
  
  if (type == PhotoType.all) {
    return galleryRepository.getAllPhotos();
  }
  
  return galleryRepository.getPhotosByType(type);
});
```