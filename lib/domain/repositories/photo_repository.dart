import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../entities/photo.dart';

/// 写真リポジトリのインターフェース
abstract class PhotoRepository {
  /// 通常写真を撮影
  Future<Photo> takePhoto();
  
  /// 写真をギャラリーに保存
  Future<String> saveImageToGallery(Uint8List imageData, PhotoType type);
  
  /// 写真をデバイス内ストレージに保存
  Future<String> saveImageToStorage(Uint8List imageData, PhotoMetadata metadata);
}

/// オーバーレイ付き写真リポジトリのインターフェース
abstract class OverlayPhotoRepository {
  /// オーバーレイ付き写真を撮影
  Future<Photo> takeOverlayPhoto(Size viewSize);
  
  /// オーバーレイ情報を含む写真をデバイス内ストレージに保存
  Future<String> saveOverlayPhoto(Uint8List imageData, List<OverlayImage> overlays);
}

/// 透過PNG作成のインターフェース
abstract class TransparentPngRepository {
  /// 2枚の写真から透過PNGを作成
  Future<Photo> createTransparentPng(String image1Path, String image2Path);
  
  /// 透過PNGをデバイス内ストレージに保存
  Future<String> saveTransparentPng(Uint8List pngData, PhotoMetadata metadata);
}

/// 写真管理リポジトリのインターフェース
abstract class GalleryRepository {
  /// すべての写真を取得
  Future<List<Photo>> getAllPhotos();
  
  /// 指定した種類の写真をフィルタリングして取得
  Future<List<Photo>> getPhotosByType(PhotoType type);
  
  /// 写真を削除
  Future<void> deletePhoto(String photoId);
  
  /// 写真を共有
  Future<void> sharePhoto(String photoPath);
}
