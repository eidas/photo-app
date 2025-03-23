import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/screens/main_screen.dart';
import 'routes.dart';

// アプリ全体のナビゲーションプロバイダー
final navigationProvider = StateNotifierProvider<NavigationNotifier, int>((ref) {
  return NavigationNotifier();
});

class NavigationNotifier extends StateNotifier<int> {
  NavigationNotifier() : super(0);
  
  void setIndex(int index) {
    state = index;
  }
}

class PhotoApp extends ConsumerWidget {
  const PhotoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '写真アプリ',
      theme: ThemeData(
        // Flutter 3では colorScheme を使うようになりました
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true, // Material 3デザインを使用
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        // ボタンテーマ
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
          ),
        ),
      ),
      // ダークテーマ
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // システム設定に応じた自動テーマ切り替え
      themeMode: ThemeMode.system,
      
      // ルート設定
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      
      // メイン画面
      home: const MainScreen(),
    );
  }
}
