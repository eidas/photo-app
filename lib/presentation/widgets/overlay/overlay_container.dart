import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/photo.dart';
import '../../providers/overlay_provider.dart';

/// オーバーレイ画像コンテナ
/// カメラプレビュー上に重ねて表示するオーバーレイ画像を管理するコンテナ
class OverlayContainer extends ConsumerWidget {
  final List<OverlayImage> overlays;
  
  const OverlayContainer({
    Key? key,
    required this.overlays,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // オーバーレイがない場合は何も表示しない
    if (overlays.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 選択中のオーバーレイID
    final selectedOverlayId = ref.watch(selectedOverlayProvider);
    
    return Stack(
      children: [
        // オーバーレイ画像をスタック表示
        ...overlays.map((overlay) {
          final isSelected = overlay.id == selectedOverlayId;
          return OverlayImageWidget(
            key: ValueKey(overlay.id),
            overlay: overlay,
            isSelected: isSelected,
            onTap: () {
              ref.read(selectedOverlayProvider.notifier).state = overlay.id;
            },
            onUpdate: (updatedOverlay) {
              ref.read(overlayProvider.notifier).updateOverlay(
                overlay.id,
                x: updatedOverlay.x,
                y: updatedOverlay.y,
                scale: updatedOverlay.scale,
                rotation: updatedOverlay.rotation,
              );
            },
            onDelete: () {
              ref.read(overlayProvider.notifier).removeOverlay(overlay.id);
              ref.read(selectedOverlayProvider.notifier).state = null;
            },
          );
        }),
      ],
    );
  }
}

/// オーバーレイ画像ウィジェット
/// 個々のオーバーレイ画像を表示し、操作を可能にするウィジェット
class OverlayImageWidget extends StatefulWidget {
  final OverlayImage overlay;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(OverlayImage) onUpdate;
  final VoidCallback onDelete;
  
  const OverlayImageWidget({
    Key? key,
    required this.overlay,
    required this.isSelected,
    required this.onTap,
    required this.onUpdate,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<OverlayImageWidget> createState() => _OverlayImageWidgetState();
}

class _OverlayImageWidgetState extends State<OverlayImageWidget> {
  late OverlayImage _overlay;
  
  // スケール・回転操作の開始値を記録
  Offset? _startOffset;
  double? _startScale;
  double? _startRotation;
  
  @override
  void initState() {
    super.initState();
    _overlay = widget.overlay;
  }
  
  @override
  void didUpdateWidget(OverlayImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // プロパティが変更されたら更新
    if (oldWidget.overlay != widget.overlay) {
      _overlay = widget.overlay;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _overlay.x,
      top: _overlay.y,
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Container(
          decoration: BoxDecoration(
            // 選択中の場合は点線枠を表示
            border: widget.isSelected 
                ? Border.all(
                    color: Colors.blue,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  )
                : null,
          ),
          child: Stack(
            children: [
              // 画像の表示
              Transform.rotate(
                angle: _overlay.rotation,
                child: Transform.scale(
                  scale: _overlay.scale,
                  child: Image.file(
                    File(_overlay.path),
                    width: _overlay.originalSize.width,
                    height: _overlay.originalSize.height,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // 選択中のみ操作ボタンを表示
              if (widget.isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _buildControlButtons(),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// コントロールボタンの表示
  Widget _buildControlButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 削除ボタン
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white, size: 20),
            onPressed: widget.onDelete,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
          // リセットボタン
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: _resetTransformation,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 変形をリセット
  void _resetTransformation() {
    setState(() {
      _overlay = _overlay.copyWith(
        scale: 1.0,
        rotation: 0.0,
      );
    });
    widget.onUpdate(_overlay);
  }
  
  /// スケール操作開始
  void _onScaleStart(ScaleStartDetails details) {
    _startOffset = Offset(_overlay.x, _overlay.y);
    _startScale = _overlay.scale;
    _startRotation = _overlay.rotation;
  }
  
  /// スケール操作中
  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_startOffset == null || _startScale == null || _startRotation == null) {
      return;
    }
    
    setState(() {
      if (details.pointerCount == 1) {
        // 移動操作
        _overlay = _overlay.copyWith(
          x: _startOffset!.dx + details.focalPointDelta.dx,
          y: _startOffset!.dy + details.focalPointDelta.dy,
        );
      } else if (details.pointerCount >= 2) {
        // 拡大縮小と回転
        _overlay = _overlay.copyWith(
          scale: (_startScale! * details.scale).clamp(0.1, 3.0),
          rotation: _startRotation! + details.rotation,
        );
      }
    });
  }
  
  /// スケール操作終了
  void _onScaleEnd(ScaleEndDetails details) {
    // 操作完了時に更新通知
    widget.onUpdate(_overlay);
    
    // 開始値をリセット
    _startOffset = null;
    _startScale = null;
    _startRotation = null;
  }
}
