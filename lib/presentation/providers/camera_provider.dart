import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../../data/datasources/camera_data_source.dart';
import '../../data/repositories/photo_repository_impl.dart';
import '../../data/repositories/storage_repository_impl.dart';
import '../../domain/repositories/photo_repository.dart';

/// カメラリスト取得プロバイダー
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  try {
    return await availableCameras();
  } catch (e) {
    return [];
  }
});

/// 選択中のカメラプロバイダー
final selectedCameraProvider = StateProvider<CameraDescription?>((ref) {
  final cameras = ref.watch(availableCamerasProvider);
  return cameras.when(
    data: (cameras) => cameras.isNotEmpty ? cameras.first : null,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// カメラコントローラーの状態プロバイダー
final cameraControllerProvider = StateNotifierProvider<CameraControllerNotifier, CameraController?>((ref) {
  final selectedCamera = ref.watch(selectedCameraProvider);
  if (selectedCamera == null) {
    return CameraControllerNotifier(null);
  }
  return CameraControllerNotifier(selectedCamera);
});

/// カメラコントローラーの状態管理クラス
class CameraControllerNotifier extends StateNotifier<CameraController?> {
  final CameraDescription? camera;
  CameraDataSource? _cameraDataSource;
  
  CameraControllerNotifier(this.camera) : super(null);
  
  /// カメラの初期化
  Future<void> initialize() async {
    if (camera == null) return;
    
    try {
      // 既存のリソースを解放
      await dispose();
      
      // カメラデータソースの初期化
      _cameraDataSource = CameraDataSourceImpl(camera!);
      await _cameraDataSource!.initialize();
      
      // Flutter 3ではCameraDataSourceの内部実装から直接コントローラーを取得
      state = (_cameraDataSource as CameraDataSourceImpl).controller;
    } catch (e) {
      state = null;
      rethrow;
    }
  }
  
  /// リソースの解放
  Future<void> dispose() async {
    try {
      if (_cameraDataSource != null) {
        await _cameraDataSource!.dispose();
        _cameraDataSource = null;
      }
      state = null;
    } catch (e) {
      // エラーを無視
    }
  }
}

/// カメラデータソースプロバイダー
final cameraDataSourceProvider = Provider<CameraDataSource>((ref) {
  final selectedCamera = ref.watch(selectedCameraProvider);
  if (selectedCamera == null) {
    throw Exception('カメラが利用できません');
  }
  return CameraDataSourceImpl(selectedCamera);
});

/// ストレージリポジトリプロバイダー
final storageRepositoryProvider = Provider<StorageRepositoryImpl>((ref) {
  return StorageRepositoryImpl();
});

/// 写真リポジトリプロバイダー
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final cameraDataSource = ref.watch(cameraDataSourceProvider);
  final storageRepository = ref.watch(storageRepositoryProvider);
  return PhotoRepositoryImpl(cameraDataSource, storageRepository);
});

/// オーバーレイ付き写真リポジトリプロバイダー
final overlayPhotoRepositoryProvider = Provider<OverlayPhotoRepository>((ref) {
  final cameraDataSource = ref.watch(cameraDataSourceProvider);
  final storageRepository = ref.watch(storageRepositoryProvider);
  final overlayManager = ref.watch(overlayManagerProvider.notifier);
  return OverlayPhotoRepositoryImpl(cameraDataSource, storageRepository, overlayManager);
});

// オーバーレイマネージャープロバイダーはオーバーレイプロバイダーファイルで定義
