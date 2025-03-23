# 写真アプリ詳細設計書

本リポジトリは、写真アプリ（オーバーレイ撮影機能と透過PNG作成機能付き）の詳細設計書です。

## 概要

このアプリはスマートフォン（Android、iPhone）で利用可能な写真アプリで、通常の撮影機能に加えて、オーバーレイ撮影機能と透過PNG作成機能を提供します。Flutter技術スタックを採用し、クリーンアーキテクチャパターンに基づいて設計されています。

## 技術スタック

- Flutter 3.x / Dart
- flutter_riverpod（状態管理）
- Camera Package（カメラ制御）
- Image Package（画像処理）

## 主な機能

- 通常撮影機能
- オーバーレイ撮影機能（透過PNGを重ねた写真撮影）
- 透過PNG作成機能（2枚の写真から差分検出）
- ギャラリー機能（写真管理、フィルタリング、共有）

## 詳細設計内容

詳細設計書は全体のボリュームが大きいため、5つのパートに分けています：

1. [詳細設計書（メイン部分）](./detailed-design.md) - 技術選定、システム構成、カメラ機能の詳細実装
2. [詳細設計書（パート2）](./detailed-design-part2.md) - ギャラリー機能、データ管理設計、画面遷移と状態管理
3. [詳細設計書（パート3）](./detailed-design-part3.md) - パフォーマンス最適化、エラー処理
4. [詳細設計書（パート4）](./detailed-design-part4.md) - エラー処理（続き）、アプリ初期化と設定、プラットフォーム対応
5. [詳細設計書（パート5）](./detailed-design-part5.md) - テスト方針、デプロイメント設定、まとめ

### Flutter 3対応について

元々の設計書はFlutter 2をベースに作成されていましたが、[Flutter 3対応のための詳細設計変更点](./updated-design-flutter3.md)にて最新のFlutter 3の機能に対応するための変更をまとめています。主な変更点としては：

- Null Safety対応の完全化
- 最新の状態管理手法（Riverpod 2.x）の採用
- Flutter 3のAPI変更への対応
- パフォーマンス最適化
- Material 3デザインの導入

## 環境要件

- Android 8.0以上
- iOS 13.0以上

## 依存パッケージ

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.5
  
  # 状態管理
  flutter_riverpod: ^2.3.6
  
  # カメラと画像処理
  camera: ^0.10.5+2
  image_picker: ^0.8.7+5
  image: ^4.0.17
  path_provider: ^2.1.0
  permission_handler: ^10.4.0
  
  # ユーティリティ
  uuid: ^3.0.7
  share_plus: ^7.0.0
  image_gallery_saver: ^2.0.3
  
  # UI関連
  flutter_svg: ^2.0.7
  cached_network_image: ^3.2.3
```

## 実装ポイント

- クリーンアーキテクチャによる関心の分離
- カメラプレビューは30fps以上のパフォーマンス
- オーバーレイ操作のレスポンスは100ms以内
- 透過PNG作成処理は5秒以内に完了
- ギャラリー表示は100枚以上の画像でもスムーズにスクロール

## 設計の特徴

- 拡張性の高いアーキテクチャ設計
- プラットフォーム（Android、iOS）固有の実装の抽象化
- エラーハンドリングの一元管理
- メモリ使用の最適化
- レスポンシブなUI設計
- Flutter 3の新機能の活用
