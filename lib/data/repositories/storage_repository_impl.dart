import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/photo.dart';

/// ストレージリポジトリの実装クラス
class StorageRepositoryImpl {
  final String _appDirName = 'photo_app';
  final String _metadataFileName = 'metadata.json';
  final _uuid = const Uuid();
  
  /// アプリ専用ディレクトリの取得
  Future<Directory> get _appDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final directory = Directory('${appDir.path}/$_appDirName');
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    return directory;
  }
  
  /// メタデータファイルの取得
  Future<File> get _metadataFile async {
    final dir = await _appDir;
    return File('${dir.path}/$_metadataFileName');
  }
  
  /// メタデータをJSONとして保存
  Future<void> _saveMetadata(Map<String, dynamic> metadata) async {
    final file = await _metadataFile;
    final jsonString = jsonEncode(metadata);
    await file.writeAsString(jsonString);
  }
  
  /// メタデータをJSONから読み込み
  Future<Map<String, dynamic>> _loadMetadata() async {
    final file = await _metadataFile;
    
    if (await file.exists()) {
      try {
        final jsonString = await file.readAsString();
        return jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        if (kDebugMode) {
          print('メタデータの読み込みに失敗しました: $e');
        }
        return {'photos': {}};
      }
    }
    
    return {'photos': {}};
  }
  
  /// 写真を保存
  Future<String> savePhoto(
    Uint8List photoData,
    PhotoMetadata metadata, {
    bool saveToGallery = true,
  }) async {
    final dir = await _appDir;
    final photoId = _uuid.v4();
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
      try {
        final result = await ImageGallerySaver.saveImage(
          photoData,
          quality: 90,
          name: 'PhotoApp_${metadata.type.toString()}_$photoId',
        );
        
        if (kDebugMode) {
          print('ギャラリーへの保存結果: $result');
        }
      } catch (e) {
        if (kDebugMode) {
          print('ギャラリーへの保存に失敗しました: $e');
        }
        // エラーは無視して処理を続行
      }
    }
    
    return photoPath;
  }
  
  /// 透過PNGを保存
  Future<String> saveTransparentPng(
    Uint8List pngData,
    PhotoMetadata metadata, {
    bool saveToGallery = true,
  }) async {
    final dir = await _appDir;
    final photoId = _uuid.v4();
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
      try {
        final result = await ImageGallerySaver.saveImage(
          pngData,
          quality: 100,
          name: 'PhotoApp_TransparentPNG_$photoId',
        );
        
        if (kDebugMode) {
          print('ギャラリーへの保存結果: $result');
        }
      } catch (e) {
        if (kDebugMode) {
          print('ギャラリーへの保存に失敗しました: $e');
        }
      }
    }
    
    return photoPath;
  }
  
  /// すべての写真を取得
  Future<List<Photo>> getAllPhotos() async {
    final allMetadata = await _loadMetadata();
    final photos = allMetadata['photos'] as Map<String, dynamic>? ?? {};
    
    final List<Photo> result = [];
    
    for (final entry in photos.entries) {
      final id = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final path = data['path'] as String;
      final metadata = PhotoMetadata.fromJson(data['metadata'] as Map<String, dynamic>);
      
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
  
  /// 写真を削除
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
  
  /// 写真を種類でフィルタリング
  Future<List<Photo>> getPhotosByType(PhotoType type) async {
    if (type == PhotoType.all) {
      return getAllPhotos();
    }
    
    final photos = await getAllPhotos();
    return photos.where((photo) => photo.metadata.type == type).toList();
  }
  
  /// 一時ファイルを作成
  Future<File> createTempFile(String extension) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/${_uuid.v4()}.$extension';
    return File(tempPath);
  }
  
  /// キャッシュの削除
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create();
      }
    } catch (e) {
      if (kDebugMode) {
        print('キャッシュのクリアに失敗しました: $e');
      }
    }
  }
}
