import 'package:flutter/material.dart';
import '../app.dart';

/// 両画面で共有するフィルターチップ共通ウィジェット。
///
/// 使い方:
///   FilterChipBar(
///     children: [
///       AppFilterChip(label: '全期間', selected: true, onTap: () {}),
///       const FilterBarDivider(),
///       AppFilterChip(label: '今月', selected: false, onTap: () {}),
///     ],
///   )
class FilterChipBar extends StatelessWidget {
  final List<Widget> children;

  const FilterChipBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: children),
    );
  }
}

/// フィルターチップひとつ。選択状態で色を切り替える。
class AppFilterChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.appInk : AppColors.appCream,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: AppColors.appInk.withAlpha(40)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize:   12,
            color:      selected ? AppColors.appPaper : AppColors.appInk,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// フィルタグループ間の縦区切り線。
class FilterBarDivider extends StatelessWidget {
  const FilterBarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color:  AppColors.appInk.withAlpha(30),
    );
  }
}
