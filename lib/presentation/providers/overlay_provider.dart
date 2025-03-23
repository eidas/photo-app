import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/photo.dart';

/// オーバーレイ画像管理プロバイダー
final overlayProvider = StateNotifierProvider<OverlayManagerNotifier, List<OverlayImage>>((ref) {
  return OverlayManagerNotifier();
});

/// オーバーレイマネージャーの状態管理クラス
class OverlayManagerNotifier extends StateNotifier<List<OverlayImage>> {
  static const int _maxOverlays = 10; // 最大オーバーレイ数
  final _uuid = const Uuid();
  
  OverlayManagerNotifier() : super([]);
  
  /// オーバーレイを追加
  void addOverlay(OverlayImage overlay) {
    // 最大オーバーレイ数を超える場合は追加しない
    if (state.length >= _maxOverlays) {
      return;
    }
    
    // IDが指定されていない場合は新しいIDを生成
    final OverlayImage newOverlay = overlay.id.isEmpty
        ? overlay.copyWith(id: _uuid.v4())
        : overlay;
    
    state = [...state, newOverlay];
  }
  
  /// オーバーレイを削除
  void removeOverlay(String id) {
    state = state.where((overlay) => overlay.id != id).toList();
  }
  
  /// オーバーレイを更新
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
  
  /// オーバーレイの順序を変更
  void reorderOverlay(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.length || 
        newIndex < 0 || newIndex >= state.length) {
      return;
    }
    
    final overlays = List<OverlayImage>.from(state);
    final overlay = overlays.removeAt(oldIndex);
    overlays.insert(newIndex, overlay);
    
    state = overlays;
  }
  
  /// オーバーレイをすべて削除
  void clearOverlays() {
    state = [];
  }
  
  /// 既存のオーバーレイデータから状態を設定
  void setOverlays(List<OverlayImage> overlays) {
    // 最大数を超える場合は切り詰める
    if (overlays.length > _maxOverlays) {
      state = overlays.sublist(0, _maxOverlays);
    } else {
      state = overlays;
    }
  }
  
  /// JSONデータからオーバーレイを読み込む
  void loadFromJson(List<Map<String, dynamic>> overlayInfoList) {
    final overlays = overlayInfoList.map((info) {
      final double x = info['x'] as double? ?? 0.0;
      final double y = info['y'] as double? ?? 0.0;
      final double scale = info['scale'] as double? ?? 1.0;
      final double rotation = info['rotation'] as double? ?? 0.0;
      final String path = info['path'] as String;
      final String id = info['id'] as String? ?? _uuid.v4();
      
      // デフォルトのサイズを設定（実際の画像サイズは後で計算）
      final Size defaultSize = const Size(100, 100);
      
      return OverlayImage(
        id: id,
        path: path,
        x: x,
        y: y,
        scale: scale,
        rotation: rotation,
        originalSize: defaultSize,
      );
    }).toList();
    
    setOverlays(overlays);
  }
}

/// 選択中のオーバーレイプロバイダー
final selectedOverlayProvider = StateProvider<String?>((ref) => null);

/// 選択中のオーバーレイを取得するプロバイダー
final activeOverlayProvider = Provider<OverlayImage?>((ref) {
  final selectedId = ref.watch(selectedOverlayProvider);
  final overlays = ref.watch(overlayProvider);
  
  if (selectedId == null) return null;
  
  return overlays.firstWhere(
    (overlay) => overlay.id == selectedId,
    orElse: () => null,
  );
});
