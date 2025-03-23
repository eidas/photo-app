import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/photo.dart';
import '../../providers/overlay_provider.dart';

/// カメラ操作コントロールパネル
class CameraControls extends ConsumerWidget {
  final CameraMode mode;
  final Future<void> Function() onCapture;
  final bool isCapturing;
  
  const CameraControls({
    Key? key,
    required this.mode,
    required this.onCapture,
    this.isCapturing = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // オーバーレイモードの場合は、オーバーレイリスト表示
            if (mode == CameraMode.overlay) _buildOverlayControls(ref),
            
            const SizedBox(height: 16),
            
            // 撮影ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 撮影ボタン
                _buildCaptureButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// 撮影ボタン
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: isCapturing ? null : onCapture,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.shade300,
            width: 4,
          ),
          // 撮影中は色を変える
          boxShadow: isCapturing
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 4,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isCapturing ? Colors.blue : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade800,
                width: 2,
              ),
            ),
            child: isCapturing
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
  
  /// オーバーレイコントロール
  Widget _buildOverlayControls(WidgetRef ref) {
    final overlays = ref.watch(overlayProvider);
    final selectedId = ref.watch(selectedOverlayProvider);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (overlays.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: overlays.length,
              itemBuilder: (context, index) {
                final overlay = overlays[index];
                final isSelected = overlay.id == selectedId;
                
                return GestureDetector(
                  onTap: () {
                    ref.read(selectedOverlayProvider.notifier).state = overlay.id;
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: isSelected
                          ? Border.all(color: Colors.blue, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        overlay.path,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        
        const SizedBox(height: 8),
        
        // オーバーレイ管理ボタン
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 追加ボタン
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('追加'),
              onPressed: () {
                _showOverlaySelectionDialog(ref.context, ref);
              },
            ),
            
            const SizedBox(width: 16),
            
            // クリアボタン
            if (overlays.isNotEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.clear_all),
                label: const Text('クリア'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ref.read(overlayProvider.notifier).clearOverlays();
                  ref.read(selectedOverlayProvider.notifier).state = null;
                },
              ),
          ],
        ),
      ],
    );
  }
  
  /// オーバーレイ選択ダイアログ
  Future<void> _showOverlaySelectionDialog(BuildContext context, WidgetRef ref) async {
    // 実際のアプリでは、透過PNGの一覧を取得して表示する
    // ここではサンプルとして、空のダイアログを表示
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('オーバーレイを選択'),
          content: const Text('利用可能なオーバーレイがありません。\n透過PNG作成画面から新しいオーバーレイを作成してください。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}
