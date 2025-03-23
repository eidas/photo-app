import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/photo.dart';
import '../providers/permission_provider.dart';
import 'camera_screen.dart';
import 'gallery_screen.dart';
import 'transparent_png_screen.dart';

/// アプリのメイン画面（タブ切り替え）
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;
  
  // 各タブに対応する画面
  final List<Widget> _screens = const [
    CameraScreen(mode: CameraMode.normal),
    CameraScreen(mode: CameraMode.overlay),
    TransparentPngScreen(),
    GalleryScreen(),
  ];
  
  // タブのタイトル
  final List<String> _titles = const [
    '通常撮影',
    'オーバーレイ撮影',
    '透過PNG作成',
    'ギャラリー',
  ];
  
  // タブのアイコン
  final List<IconData> _icons = const [
    Icons.camera_alt,
    Icons.layers,
    Icons.auto_fix_high,
    Icons.photo_library,
  ];
  
  @override
  void initState() {
    super.initState();
    // 起動時に権限チェック
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionProvider.notifier).checkAndRequestPermissions();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // 権限状態を監視
    final permissionState = ref.watch(permissionProvider);
    
    return Scaffold(
      body: permissionState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        granted: () => _screens[_selectedIndex],
        denied: (message) => _buildPermissionDeniedView(message),
      ),
      bottomNavigationBar: permissionState.maybeWhen(
        granted: () => _buildBottomNavigationBar(),
        orElse: () => null,
      ),
    );
  }
  
  /// 権限が拒否された場合の表示
  Widget _buildPermissionDeniedView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(permissionProvider.notifier).openAppSettings();
              },
              child: const Text('アプリ設定を開く'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// ボトムナビゲーションバーのビルド
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onTabTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey,
      items: List.generate(
        _titles.length,
        (index) => BottomNavigationBarItem(
          icon: Icon(_icons[index]),
          label: _titles[index],
        ),
      ),
    );
  }
  
  /// タブ選択時の処理
  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
