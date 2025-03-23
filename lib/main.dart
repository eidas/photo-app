import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter初期化を確実に行う
  
  runApp(
    // アプリ全体をProviderScopeでラップしてRiverpodを使用可能に
    const ProviderScope(
      child: PhotoApp(),
    ),
  );
}
