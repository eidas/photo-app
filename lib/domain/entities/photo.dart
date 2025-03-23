import 'package:flutter/material.dart';

/// 写真の種類を表す列挙型
enum PhotoType {
  all,     // フィルタリング用
  normal,  // 通常写真
  overlay, // オーバーレイ写真
  transparentPng, // 透過PNG
}

/// 写真のメタデータを保持するクラス
class PhotoMetadata {
  final DateTime createdAt;
  final PhotoType type;
  final List<Map<String, dynamic>>? overlayInfo; // オーバーレイ情報（オプション）
  
  const PhotoMetadata({
    required this.createdAt,
    required this.type,
    this.overlayInfo,
  });
  
  /// JSONに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'type': type.toString(),
      'overlayInfo': overlayInfo,
    };
  }
  
  /// JSONからインスタンスを作成するファクトリメソッド
  factory PhotoMetadata.fromJson(Map<String, dynamic> json) {
    return PhotoMetadata(
      createdAt: DateTime.parse(json['createdAt'] as String),
      type: PhotoType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PhotoType.normal,
      ),
      overlayInfo: json['overlayInfo'] != null
          ? List<Map<String, dynamic>>.from(json['overlayInfo'] as List)
          : null,
    );
  }
}

/// 写真を表すエンティティクラス
class Photo {
  final String id;
  final String path;
  final PhotoMetadata metadata;
  
  const Photo({
    required this.id,
    required this.path,
    required this.metadata,
  });
}

/// オーバーレイ画像を表すクラス
class OverlayImage {
  final String id;
  final String path;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final Size originalSize;
  
  const OverlayImage({
    required this.id,
    required this.path,
    this.x = 0.0,
    this.y = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
    required this.originalSize,
  });
  
  /// 新しいプロパティを持つOverlayImageを作成
  OverlayImage copyWith({
    String? id,
    String? path,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    Size? originalSize,
  }) {
    return OverlayImage(
      id: id ?? this.id,
      path: path ?? this.path,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      originalSize: originalSize ?? this.originalSize,
    );
  }
}

/// カメラモードを表す列挙型
enum CameraMode {
  normal,  // 通常撮影モード
  overlay, // オーバーレイ撮影モード
}
