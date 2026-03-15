import 'package:flutter/material.dart';

/// アプリ全体で使用する汎用バッジウィジェット。
///
/// [text] に表示文字列、[color] にブランドカラーを指定すると
/// 背景 12% 透過・テキスト同色で統一スタイルのバッジを描画する。
class InfoBadge extends StatelessWidget {
  final String text;
  final Color  color;

  const InfoBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withAlpha(30),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w500,
          color:      color,
        ),
      ),
    );
  }
}
