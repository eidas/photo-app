import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// カメラデータソースの抽象クラス
abstract class CameraDataSource {
  /// カメラを初期化
  Future<void> initialize();
  
  /// カメラプレビューストリームを取得
  Stream<CameraImage> getPreviewStream();
  
  /// 写真を撮影
  Future<Uint8List> capturePhoto();
  
  /// リソースを解放
  Future<void> dispose();
}

/// カメラデータソースの実装クラス
class CameraDataSourceImpl implements CameraDataSource {
  late CameraController _cameraController;
  final CameraDescription _camera;
  final ResolutionPreset _resolutionPreset;
  
  CameraDataSourceImpl(
    this._camera, {
    ResolutionPreset resolutionPreset = ResolutionPreset.high,
  }) : _resolutionPreset = resolutionPreset;
  
  @override
  Future<void> initialize() async {
    try {
      _cameraController = CameraController(
        _camera,
        _resolutionPreset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg, // Flutter 3では明示的に形式指定が推奨
      );
      
      await _cameraController.initialize();
      
      // フラッシュモードを自動に設定
      if (_cameraController.value.isInitialized) {
        await _cameraController.setFlashMode(FlashMode.auto);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('カメラの初期化に失敗しました: $e');
      }
      rethrow;
    }
  }
  
  @override
  Stream<CameraImage> getPreviewStream() {
    if (!_cameraController.value.isInitialized) {
      throw Exception('カメラが初期化されていません');
    }
    
    // Flutter 3では非同期で開始する
    return _cameraController.startImageStream();
  }
  
  @override
  Future<Uint8List> capturePhoto() async {
    if (!_cameraController.value.isInitialized) {
      throw Exception('カメラが初期化されていません');
    }
    
    try {
      // 撮影前に自動フォーカスを実行
      await _cameraController.setFocusMode(FocusMode.auto);
      await Future.delayed(const Duration(milliseconds: 300)); // フォーカス待機
      
      final XFile file = await _cameraController.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      if (kDebugMode) {
        print('写真の撮影に失敗しました: $e');
      }
      rethrow;
    }
  }
  
  @override
  Future<void> dispose() async {
    if (_cameraController.value.isInitialized) {
      // Flutter 3ではstreamが実行中の場合は停止する
      try {
        await _cameraController.stopImageStream();
      } catch (e) {
        // すでに停止している場合はエラーを無視
      }
      
      await _cameraController.dispose();
    }
  }
  
  // カメラコントローラを直接取得 (一部のAPI直接アクセス用)
  CameraController get controller => _cameraController;
}
