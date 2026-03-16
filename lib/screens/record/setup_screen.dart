import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../constants/game_type.dart';
import '../../models/shop.dart';
import '../../providers/shop_provider.dart';
import '../../widgets/banner_ad_widget.dart';
import 'session_input_screen.dart';

// ─── レートの選択肢 ─────────────────────────────────────────────────────────
const _rateOptions   = [0, 1, 2, 3, 5, 10, 20, 30, 50];
const _formatOptions = ['東南戦', '東風戦', 'その他'];

// ─── SharedPreferences キー ──────────────────────────────────────────────────
const _kDraft      = 'session_draft';

// SegmentedButton 共通スタイル（AppInk ベース）
final _segStyle = SegmentedButton.styleFrom(
  selectedBackgroundColor: AppColors.appInk,
  selectedForegroundColor: AppColors.appPaper,
  foregroundColor:         AppColors.appInk,
  side: BorderSide(color: AppColors.appInk.withAlpha(77)),
);

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  DateTime _date     = DateTime.now();
  String   _gameType = GameType.free;
  String   _shopName = '';
  int      _rule     = 0;
  int      _players  = 4;
  String   _format   = '東南戦';
  int      _chipUnit = 0;
  int      _gameFee  = 0;
  int      _topPrize = 0;

  Shop? _selectedPreset;
  late final TextEditingController _shopCtrl;

  @override
  void initState() {
    super.initState();
    _shopCtrl = TextEditingController(text: _shopName);
  }

  @override
  void dispose() {
    _shopCtrl.dispose();
    super.dispose();
  }

  // ── プリセット適用 ─────────────────────────────────────────────────────────
  void _applyPreset(Shop? shop) {
    setState(() {
      _selectedPreset = shop;
      if (shop == null) return;
      _shopName = shop.name;
      _shopCtrl.text = shop.name;
      _players  = shop.players;
      _format   = shop.format;
      _rule     = shop.rule;
      _chipUnit = shop.chipUnit;
      _gameFee  = shop.gameFee;
      _topPrize = shop.topPrize;
    });
  }

  // ── セッション開始（ドラフトチェック付き）──────────────────────────────────
  Future<void> _startSession() async {
    _shopName = _shopCtrl.text.trim();

    final p        = await SharedPreferences.getInstance();
    final draftStr = p.getString(_kDraft);
    Map<String, dynamic>? draft;

    if (draftStr != null && mounted) {
      final resume = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title:   const Text('前回の入力が残っています'),
          content: const Text('前回の入力の続きから再開しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('新しく始める'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('再開する'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (resume == true) {
        draft = jsonDecode(draftStr) as Map<String, dynamic>;
      } else {
        await p.remove(_kDraft);
      }
    }

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionInputScreen(
        date:     _date,
        gameType: _gameType,
        shopName: _shopName,
        rule:     _rule,
        players:  _players,
        format:   _format,
        chipUnit: _chipUnit,
        gameFee:  _gameFee,
        topPrize: _topPrize,
        draft:    draft,
      ),
    ));
  }

  // ── 日付選択 ──────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date,
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final shops = ref.watch(shopProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      appBar: AppBar(title: const Text('記録する')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── スクロール可能なフォームエリア ─────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 日付 ──────────────────────────────────────────────
                  _SectionCard(
                    label: '日付',
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('yyyy年M月d日 (E)', 'ja').format(_date),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 種別 ──────────────────────────────────────────────
                  _SectionCard(
                    label: '種別',
                    child: Row(
                      children: [
                        Expanded(child: _ToggleBtn(
                          label:    'フリー',
                          selected: _gameType == GameType.free,
                          onTap:    () => setState(() => _gameType = GameType.free),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _ToggleBtn(
                          label:    'セット',
                          selected: _gameType == GameType.set,
                          onTap:    () => setState(() => _gameType = GameType.set),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 店舗プリセット ─────────────────────────────────────
                  if (shops.isNotEmpty) ...[
                    _SectionCard(
                      label: '店舗プリセット',
                      child: DropdownButton<Shop?>(
                        value:      _selectedPreset,
                        isExpanded: true,
                        underline:  const SizedBox.shrink(),
                        hint:       const Text('プリセット選択（任意）'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('--- 選択解除 ---')),
                          ...shops.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.name),
                              )),
                        ],
                        onChanged: _applyPreset,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── 店舗名 ─────────────────────────────────────────────
                  _SectionCard(
                    label: '店舗名（任意）',
                    child: TextField(
                      controller: _shopCtrl,
                      decoration: const InputDecoration(
                        hintText: '店舗名を入力',
                        border:   InputBorder.none,
                        isDense:  true,
                      ),
                      onChanged: (v) => _shopName = v,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── レート ────────────────────────────────────────────
                  _SectionCard(
                    label: 'レート',
                    child: DropdownButton<int>(
                      value:      _rule,
                      isExpanded: true,
                      underline:  const SizedBox.shrink(),
                      items: _rateOptions.map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r == 0 ? '未設定' : '$r点'),
                      )).toList(),
                      onChanged: (v) => setState(() => _rule = v ?? 0),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 人数 ──────────────────────────────────────────────
                  _SectionCard(
                    label: '人数',
                    child: SegmentedButton<int>(
                      style: _segStyle,
                      segments: const [
                        ButtonSegment(value: 4, label: Text('4人')),
                        ButtonSegment(value: 3, label: Text('3人')),
                      ],
                      selected: {_players},
                      onSelectionChanged: (s) =>
                          setState(() => _players = s.first),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 戦型 ──────────────────────────────────────────────
                  _SectionCard(
                    label: '戦型',
                    child: DropdownButton<String>(
                      value:      _format,
                      isExpanded: true,
                      underline:  const SizedBox.shrink(),
                      items: _formatOptions.map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f),
                      )).toList(),
                      onChanged: (v) =>
                          setState(() => _format = v ?? '東南戦'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── 固定ボタンエリア ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            color: AppColors.appPaper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: _startSession,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.appInk,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('セッション開始',
                      style: TextStyle(
                          fontSize: 16, color: AppColors.appPaper)),
                ),
              ],
            ),
          ),
          const Center(child: BannerAdWidget()),
        ],
      ),
      ),
    );
  }
}

// ── 小部品 ─────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String label;
  final Widget child;
  const _SectionCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.appCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.appInk.withAlpha(51), width: 1),
        boxShadow: [
          BoxShadow(
            color:      AppColors.appInk.withAlpha(12),
            blurRadius: 3,
            offset:     const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize:     11,
                color:        AppColors.appInk.withAlpha(191),
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:        selected ? AppColors.appInk : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.appInk.withAlpha(selected ? 0 : 102)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color:      selected ? AppColors.appPaper : AppColors.appInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
