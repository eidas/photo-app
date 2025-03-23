import 'package:flutter/material.dart';
import '../domain/entities/photo.dart';
import '../presentation/screens/camera_screen.dart';
import '../presentation/screens/gallery_screen.dart';
import '../presentation/screens/main_screen.dart';
import '../presentation/screens/photo_detail_screen.dart';
import '../presentation/screens/transparent_png_screen.dart';

/// アプリケーションのルート定義
class AppRoutes {
  static const String home = '/';
  static const String camera = '/camera';
  static const String overlay = '/overlay';
  static const String transparentPng = '/transparent_png';
  static const String gallery = '/gallery';
  static const String photoDetail = '/photo_detail';
  
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const MainScreen(),
        );
      case camera:
        final CameraMode mode = settings.arguments as CameraMode? ?? CameraMode.normal;
        return MaterialPageRoute(
          builder: (_) => CameraScreen(mode: mode),
        );
      case gallery:
        return MaterialPageRoute(
          builder: (_) => const GalleryScreen(),
        );
      case photoDetail:
        final photo = settings.arguments as Photo;
        return MaterialPageRoute(
          builder: (_) => PhotoDetailScreen(photo: photo),
        );
      case transparentPng:
        return MaterialPageRoute(
          builder: (_) => const TransparentPngScreen(),
        );
      default:
        return null;
    }
  }
}
