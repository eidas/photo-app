import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/photo.dart';
import '../../domain/repositories/photo_repository.dart';
import '../datasources/camera_data_source.dart';
import 'storage_repository_impl.dart';

/// 写真リポジトリの実装クラス
class PhotoRepositoryImpl implements PhotoRepository {
  final CameraDataSource _cameraDataSource;
  final StorageRepositoryImpl _storageRepository;
  final _uuid = const Uuid();
  
  PhotoRepositoryImpl(this._cameraDataSource, this._storageRepository);
  
  @override
  Future<Photo> takePhoto() async {
    // カメラで写真を撮影
    final photoData = await _cameraDataSource.capturePhoto();
    
    // 写真のメタデータを作成
    final metadata = PhotoMetadata(
      createdAt: DateTime.now(),
      type: PhotoType.normal,
    );
    
    // 写真をデバイスに保存
    final savedPhotoPath = await _storageRepository.savePhoto(
      photoData, 
      metadata,
      saveToGallery: true,
    );
    
    return Photo(
      id: _uuid.v4(),
      path: savedPhotoPath,
      metadata: metadata,
    );
  }
  
  @override
  Future<String> saveImageToGallery(Uint8List imageData, PhotoType type) async {
    final metadata = PhotoMetadata(
      createdAt: DateTime.now(),
      type: type,
    );
    
    return await _storageRepository.savePhoto(
      imageData,
      metadata,
      saveToGallery: true,
    );
  }
  
  @override
  Future<String> saveImageToStorage(Uint8List imageData, PhotoMetadata metadata) async {
    return await _storageRepository.savePhoto(
      imageData,
      metadata,
      saveToGallery: false,
    );
  }
}

/// オーバーレイ付き写真リポジトリの実装クラス
class OverlayPhotoRepositoryImpl implements OverlayPhotoRepository {
  final CameraDataSource _cameraDataSource;
  final StorageRepositoryImpl _storageRepository;
  final OverlayManagerNotifier _overlayManager;
  final _uuid = const Uuid();
  
  OverlayPhotoRepositoryImpl(
    this._cameraDataSource,
    this._storageRepository,
    this._overlayManager,
  );
  
  @override
  Future<Photo> takeOverlayPhoto(Size viewSize) async {
    // カメラで写真を撮影
    final photoData = await _cameraDataSource.capturePhoto();
    
    // 現在のオーバーレイ情報を取得
    final overlays = _overlayManager.state;
    
    // オーバーレイがない場合は通常の写真として保存
    if (overlays.isEmpty) {
      final metadata = PhotoMetadata(
        createdAt: DateTime.now(),
        type: PhotoType.normal,
      );
      
      final savedPhotoPath = await _storageRepository.savePhoto(
        photoData,
        metadata,
        saveToGallery: true,
      );
      
      return Photo(
        id: _uuid.v4(),
        path: savedPhotoPath,
        metadata: metadata,
      );
    }
    
    // UIキャンバスから合成画像を作成
    final compositeData = await _createCompositeImage(photoData, overlays, viewSize);
    
    // オーバーレイのメタデータを記録
    final overlayInfoList = overlays.map((overlay) => {
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
    final savedPhotoPath = await _storageRepository.savePhoto(
      compositeData,
      metadata,
      saveToGallery: true,
    );
    
    return Photo(
      id: _uuid.v4(),
      path: savedPhotoPath,
      metadata: metadata,
    );
  }
  
  @override
  Future<String> saveOverlayPhoto(
    Uint8List imageData, 
    List<OverlayImage> overlays,
  ) async {
    // オーバーレイのメタデータを記録
    final overlayInfoList = overlays.map((overlay) => {
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
    return await _storageRepository.savePhoto(
      imageData,
      metadata,
      saveToGallery: true,
    );
  }
  
  /// カメラ画像とオーバーレイを合成した画像を作成する
  Future<Uint8List> _createCompositeImage(
    Uint8List photoData, 
    List<OverlayImage> overlays,
    Size viewSize,
  ) async {
    // Flutter 3での画像処理方法
    // カメラ画像をデコード
    final ui.Image capturedImage = await decodeImageFromList(photoData);
    
    // 合成用のレコーダーとキャンバスを作成
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // キャンバスサイズ
    final canvasSize = Size(viewSize.width, viewSize.height);
    
    // カメラ画像を描画
    canvas.drawImageRect(
      capturedImage,
      Rect.fromLTWH(0, 0, capturedImage.width.toDouble(), capturedImage.height.toDouble()),
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint(),
    );
    
    // オーバーレイを描画
    for (final overlay in overlays) {
      final overlayImage = await _loadImage(overlay.path);
      final overlayRect = Rect.fromLTWH(
        overlay.x,
        overlay.y,
        overlay.originalSize.width * overlay.scale,
        overlay.originalSize.height * overlay.scale,
      );
      
      canvas.save();
      
      // 回転の中心点を計算
      final centerX = overlay.x + (overlayRect.width / 2);
      final centerY = overlay.y + (overlayRect.height / 2);
      
      // 回転の適用
      canvas.translate(centerX, centerY);
      canvas.rotate(overlay.rotation);
      canvas.translate(-centerX, -centerY);
      
      // 画像の描画
      canvas.drawImageRect(
        overlayImage,
        Rect.fromLTWH(0, 0, overlayImage.width.toDouble(), overlayImage.height.toDouble()),
        overlayRect,
        Paint(),
      );
      
      canvas.restore();
    }
    
    // 描画内容を画像として取得
    final ui.Image compositeImage = await recorder.endRecording().toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
    
    // PNGデータに変換
    final ByteData? byteData = await compositeImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to convert composite image to byte data');
    }
    
    final Uint8List pngData = byteData.buffer.asUint8List();
    
    // JPEGに変換
    return await _convertToJpeg(pngData);
  }
  
  /// 画像ファイルを読み込む
  Future<ui.Image> _loadImage(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return await decodeImageFromList(bytes);
  }
  
  /// PNG画像をJPEGに変換
  Future<Uint8List> _convertToJpeg(Uint8List pngData, {int quality = 90}) async {
    final img.Image? image = img.decodeImage(pngData);
    if (image == null) {
      throw Exception('Failed to decode PNG image');
    }
    
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
}

/// 透過PNG作成リポジトリの実装クラス
class TransparentPngRepositoryImpl implements TransparentPngRepository {
  final StorageRepositoryImpl _storageRepository;
  final _uuid = const Uuid();
  
  TransparentPngRepositoryImpl(this._storageRepository);
  
  @override
  Future<Photo> createTransparentPng(String image1Path, String image2Path) async {
    // 2枚の画像を読み込み
    final file1 = File(image1Path);
    final file2 = File(image2Path);
    
    if (!await file1.exists() || !await file2.exists()) {
      throw Exception('Image files do not exist');
    }
    
    // 透過PNG作成処理を実行
    final pngData = await _processTransparentPng(file1, file2);
    
    // メタデータ作成
    final metadata = PhotoMetadata(
      createdAt: DateTime.now(),
      type: PhotoType.transparentPng,
    );
    
    // 保存処理
    final savedPath = await saveTransparentPng(pngData, metadata);
    
    return Photo(
      id: _uuid.v4(),
      path: savedPath,
      metadata: metadata,
    );
  }
  
  @override
  Future<String> saveTransparentPng(Uint8List pngData, PhotoMetadata metadata) async {
    return await _storageRepository.saveTransparentPng(
      pngData,
      metadata,
      saveToGallery: true,
    );
  }
  
  /// 透過PNG生成処理
  Future<Uint8List> _processTransparentPng(File image1, File image2) async {
    // imageパッケージを使用した処理は別スレッドで実行
    return await compute(_transparentPngIsolate, {
      'image1Path': image1.path,
      'image2Path': image2.path,
      'threshold': 30, // 差分検出閾値
    });
  }
}

/// 分離スレッドで実行する透過PNG処理
Uint8List _transparentPngIsolate(Map<String, dynamic> params) {
  final String image1Path = params['image1Path'];
  final String image2Path = params['image2Path'];
  final int threshold = params['threshold'];
  
  // 画像ファイル読み込み
  final bytes1 = File(image1Path).readAsBytesSync();
  final bytes2 = File(image2Path).readAsBytesSync();
  
  // 画像デコード
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
    final width = img1.width < img2.width ? img1.width : img2.width;
    final height = img1.height < img2.height ? img1.height : img2.height;
    
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
      if (avgDiff > threshold) {
        alpha = 255; // 不透明
        
        // 画像1のピクセル色を使用
        resultImage.setPixel(x, y, img.getColor(r1, g1, b1, alpha));
      } else {
        // 透明なピクセル
        resultImage.setPixel(x, y, img.getColor(0, 0, 0, alpha));
      }
    }
  }
  
  // PNGとしてエンコード
  final pngData = img.encodePng(resultImage);
  return Uint8List.fromList(pngData);
}
