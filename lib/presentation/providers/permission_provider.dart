import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// 権限の状態
sealed class PermissionState {
  const PermissionState();
}

/// 権限確認中
class PermissionLoading extends PermissionState {
  const PermissionLoading();
}

/// 権限許可済み
class PermissionGranted extends PermissionState {
  const PermissionGranted();
}

/// 権限拒否
class PermissionDenied extends PermissionState {
  final String message;
  const PermissionDenied(this.message);
}

/// 権限管理プロバイダー
final permissionProvider = StateNotifierProvider<PermissionNotifier, PermissionState>((ref) {
  return PermissionNotifier();
});

/// 権限状態の管理クラス
class PermissionNotifier extends StateNotifier<PermissionState> {
  PermissionNotifier() : super(const PermissionLoading());
  
  /// 必要な権限を確認し、必要に応じてリクエスト
  Future<void> checkAndRequestPermissions() async {
    // カメラとストレージ権限を確認
    final cameraStatus = await Permission.camera.status;
    final storageStatus = await Permission.storage.status;
    final photosStatus = await Permission.photos.status;
    
    // すべての権限が許可されているかチェック
    if (_isGranted(cameraStatus) && 
        (_isGranted(storageStatus) || _isGranted(photosStatus))) {
      state = const PermissionGranted();
      return;
    }
    
    // カメラ権限のリクエスト
    if (!_isGranted(cameraStatus)) {
      final cameraResult = await Permission.camera.request();
      if (!_isGranted(cameraResult)) {
        state = const PermissionDenied('カメラへのアクセス許可が必要です。このアプリのカメラ機能を使用するには、アプリ設定から権限を許可してください。');
        return;
      }
    }
    
    // ストレージ/写真権限のリクエスト (プラットフォームによって異なる)
    if (!_isGranted(storageStatus) && !_isGranted(photosStatus)) {
      final storageResult = await Permission.storage.request();
      final photosResult = await Permission.photos.request();
      
      if (!_isGranted(storageResult) && !_isGranted(photosResult)) {
        state = const PermissionDenied('写真ギャラリーへのアクセス許可が必要です。写真の保存や選択を行うには、アプリ設定から権限を許可してください。');
        return;
      }
    }
    
    // すべての権限が許可された
    state = const PermissionGranted();
  }
  
  /// 権限が許可されているかチェック
  bool _isGranted(PermissionStatus status) {
    return status == PermissionStatus.granted || 
           status == PermissionStatus.limited;
  }
  
  /// アプリ設定を開く
  Future<void> openAppSettings() async {
    final result = await openAppSettings();
    if (result) {
      // 設定から戻ってきたら権限を再チェック
      await checkAndRequestPermissions();
    }
  }
}
