import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../../domain/entities/photo.dart';
import '../providers/camera_provider.dart';
import '../providers/overlay_provider.dart';
import '../widgets/camera/camera_controls.dart';
import '../widgets/overlay/overlay_container.dart';

/// カメラ画面
class CameraScreen extends ConsumerStatefulWidget {
  final CameraMode mode;
  
  const CameraScreen({
    Key? key,
    required this.mode,
  }) : super(key: key);

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  late Future<void> _initializeCameraFuture;
  bool _isCapturing = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraFuture = _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    // カメラプロバイダーからカメラコントローラーを初期化
    await ref.read(cameraControllerProvider.notifier).initialize();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = ref.read(cameraControllerProvider);
    
    // アプリがバックグラウンドになった場合やフォアグラウンドに戻った場合の処理
    if (cameraController == null) return;
    
    if (state == AppLifecycleState.inactive) {
      // カメラリソースを解放
      ref.read(cameraControllerProvider.notifier).dispose();
    } else if (state == AppLifecycleState.resumed) {
      // カメラを再初期化
      _initializeCameraFuture = _initializeCamera();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeCameraFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return _buildCameraView();
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
  
  Widget _buildCameraView() {
    final cameraController = ref.watch(cameraControllerProvider);
    
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(child: Text('カメラの初期化に失敗しました'));
    }
    
    return Stack(
      children: [
        // カメラプレビュー
        Positioned.fill(
          child: _CameraPreviewWithAspectRatio(controller: cameraController),
        ),
        
        // オーバーレイモードの場合はオーバーレイを表示
        if (widget.mode == CameraMode.overlay)
          Consumer(
            builder: (context, ref, child) {
              final overlays = ref.watch(overlayProvider);
              return OverlayContainer(overlays: overlays);
            },
          ),
        
        // カメラコントロール
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: CameraControls(
            mode: widget.mode,
            onCapture: _capturePhoto,
            isCapturing: _isCapturing,
          ),
        ),
      ],
    );
  }
  
  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    
    setState(() {
      _isCapturing = true;
    });
    
    try {
      if (widget.mode == CameraMode.normal) {
        // 通常撮影モード
        await ref.read(photoRepositoryProvider).takePhoto();
      } else {
        // オーバーレイ撮影モード
        final size = MediaQuery.of(context).size;
        await ref.read(overlayPhotoRepositoryProvider).takeOverlayPhoto(size);
      }
      
      // キャプチャ成功のフィードバック
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真を保存しました')),
        );
      }
    } catch (e) {
      // エラー処理
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }
}

/// カメラプレビューをアスペクト比を考慮して表示するウィジェット
class _CameraPreviewWithAspectRatio extends StatelessWidget {
  final CameraController controller;
  
  const _CameraPreviewWithAspectRatio({
    Key? key,
    required this.controller,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Flutter 3での画面サイズ取得方法
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    
    // カメラのアスペクト比を計算
    final cameraRatio = controller.value.aspectRatio;
    
    // 画面とカメラのアスペクト比に基づいて適切なスケールを計算
    var scale = deviceRatio < cameraRatio 
        ? size.height / (size.width / cameraRatio)
        : size.width / (size.height * cameraRatio);
    
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: AspectRatio(
            aspectRatio: cameraRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
