import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../../utils/session_utils.dart';
import '../../widgets/toast_widget.dart';

class SessionInputScreen extends ConsumerStatefulWidget {
  final DateTime date;
  final String   gameType;
  final String   shopName;
  final int      rule;
  final int      players;
  final String   format;
  final int      chipUnit;
  final int      gameFee;
  final int      topPrize;

  const SessionInputScreen({
    super.key,
    required this.date,
    required this.gameType,
    required this.shopName,
    required this.rule,
    required this.players,
    required this.format,
    required this.chipUnit,
    required this.gameFee,
    required this.topPrize,
  });

  @override
  ConsumerState<SessionInputScreen> createState() => _SessionInputScreenState();
}

class _SessionInputScreenState extends ConsumerState<SessionInputScreen> {
  late int _chipUnit;

  // ── 着順カウント ──────────────────────────────────────────────────────────
  int _c1 = 0, _c2 = 0, _c3 = 0, _c4 = 0;

  // ── 収支 ──────────────────────────────────────────────────────────────────
  int _balance  = 0;
  int _chips    = 0;
  int _chipVal  = 0;
  int _venueFee = 0;

  // ── テキストコントローラ ──────────────────────────────────────────────────
  late final TextEditingController _balanceCtrl;
  late final TextEditingController _chipsCtrl;
  late final TextEditingController _chipUnitCtrl;
  late final TextEditingController _venueFeeCtrl;
  late final TextEditingController _noteCtrl;

  // ── 長押しタイマー ────────────────────────────────────────────────────────
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    _chipUnit     = widget.chipUnit;
    _balanceCtrl  = TextEditingController(text: '0');
    _chipsCtrl    = TextEditingController(text: '0');
    _chipUnitCtrl = TextEditingController(text: '$_chipUnit');
    _venueFeeCtrl = TextEditingController(text: '0');
    _noteCtrl     = TextEditingController();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _balanceCtrl.dispose();
    _chipsCtrl.dispose();
    _chipUnitCtrl.dispose();
    _venueFeeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── 着順カウント操作 ──────────────────────────────────────────────────────
  void _updateCount(int place, int delta) {
    HapticFeedback.lightImpact();
    setState(() {
      switch (place) {
        case 1: _c1 = (_c1 + delta).clamp(0, 999);
        case 2: _c2 = (_c2 + delta).clamp(0, 999);
        case 3: _c3 = (_c3 + delta).clamp(0, 999);
        case 4: _c4 = (_c4 + delta).clamp(0, 999);
      }
    });
  }

  void _startLongPress(int place, int delta) {
    _longPressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateCount(place, delta);
    });
  }

  void _stopLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  // ── 収支計算 ──────────────────────────────────────────────────────────────
  void _recalc() {
    _balance  = int.tryParse(_balanceCtrl.text)  ?? 0;
    _chips    = int.tryParse(_chipsCtrl.text)    ?? 0;
    _chipUnit = int.tryParse(_chipUnitCtrl.text) ?? 0;
    _venueFee = int.tryParse(_venueFeeCtrl.text) ?? 0;
    _chipVal  = _chips * _chipUnit;
    setState(() {});
  }

  int get _net {
    if (widget.gameType == 'free') return _balance + _chipVal;
    return _balance + _chipVal - _venueFee;
  }

  // ── 保存 ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    _recalc();
    // ゲーム数0チェック
    final totalGames = _c1 + _c2 + _c3 + (widget.players == 4 ? _c4 : 0);
    if (totalGames == 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title:   const Text('ゲーム数が0です'),
          content: const Text('ゲーム数が0ですが、このまま保存しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存する'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final session = Session(
      shop:      widget.shopName,
      date:      widget.date,
      players:   widget.players,
      format:    widget.format,
      rule:      widget.rule,
      gameType:  widget.gameType,
      count1:    _c1,
      count2:    _c2,
      count3:    _c3,
      count4:    widget.players == 4 ? _c4 : 0,
      balance:   _balance,
      chips:     _chips,
      chipUnit:  _chipUnit,
      chipVal:   _chipVal,
      venueFee:  _venueFee,
      net:       _net,
      gameFee:   widget.gameFee,
      topPrize:  widget.topPrize,
      note:      _noteCtrl.text.trim(),
    );

    await ref.read(sessionProvider.notifier).addSession(session);

    if (!mounted) return;
    final sessions = ref.read(sessionProvider);
    final todayTotal = todayNetTotal(sessions);
    Navigator.of(context).pop();
    showToast(context, '保存しました　今日: ${signedStr(todayTotal)}円');
  }

  // ── 破棄確認 ──────────────────────────────────────────────────────────────
  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('破棄しますか？'),
        content: const Text('入力内容が失われます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('破棄', style: TextStyle(color: AppColors.appRed)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isFree = widget.gameType == 'free';
    final showChip = _chipUnit > 0 || !isFree;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.shopName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                '${DateFormat('M/d').format(widget.date)}  ${widget.players}人  ${widget.format}  ${isFree ? "フリー" : "セット"}',
                style: TextStyle(fontSize: 12, color: AppColors.appInk.withAlpha(160)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (await _confirmDiscard() && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('終了・破棄',
                  style: TextStyle(color: AppColors.appRed)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 着順カウント ──────────────────────────────────────────
              _buildCountGrid(),
              const SizedBox(height: 16),

              // ── 収支入力 ──────────────────────────────────────────────
              _buildBalanceSection(isFree: isFree, showChip: showChip),
              const SizedBox(height: 16),

              // ── 純収支プレビュー ──────────────────────────────────────
              _buildNetPreview(),
              const SizedBox(height: 16),

              // ── メモ ──────────────────────────────────────────────────
              _buildMemo(),
              const SizedBox(height: 24),

              // ── 保存ボタン ────────────────────────────────────────────
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.appTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('保存する',
                    style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── 着順グリッド ──────────────────────────────────────────────────────────
  Widget _buildCountGrid() {
    final places = widget.players == 4 ? [1, 2, 3, 4] : [1, 2, 3];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing:  10,
      childAspectRatio: 1.3,
      children: places.map((p) => _CountCard(
        place:          p,
        count:          _countOf(p),
        onDecrement:    () => _updateCount(p, -1),
        onIncrement:    () => _updateCount(p, 1),
        onLongDecrement: () => _startLongPress(p, -1),
        onLongIncrement: () => _startLongPress(p, 1),
        onLongPressEnd: _stopLongPress,
      )).toList(),
    );
  }

  int _countOf(int place) {
    switch (place) {
      case 1: return _c1;
      case 2: return _c2;
      case 3: return _c3;
      default: return _c4;
    }
  }

  // ── 収支入力セクション ────────────────────────────────────────────────────
  Widget _buildBalanceSection({required bool isFree, required bool showChip}) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.appCream,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.appInk.withAlpha(15),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _InputRow(
            label: isFree ? '現金収支' : '点棒収支',
            ctrl:  _balanceCtrl,
            signed: true,
            onChanged: (_) => _recalc(),
          ),
          if (showChip) ...[
            _divider(),
            _InputRow(
              label: 'チップ枚数',
              ctrl:  _chipsCtrl,
              signed: true,
              onChanged: (_) => _recalc(),
            ),
          ],
          if (!isFree) ...[
            _divider(),
            _InputRow(
              label: 'チップ単価',
              ctrl:  _chipUnitCtrl,
              signed: false,
              onChanged: (_) => _recalc(),
            ),
          ],
          if (showChip) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text('チップ収支',
                      style: TextStyle(
                          color: AppColors.appInk.withAlpha(160), fontSize: 14)),
                  const Spacer(),
                  Text(signedStr(_chipVal),
                      style: TextStyle(
                        color: _chipVal >= 0
                            ? AppColors.appTeal
                            : AppColors.appRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      )),
                ],
              ),
            ),
          ],
          if (!isFree) ...[
            _divider(),
            _InputRow(
              label: '場代',
              ctrl:  _venueFeeCtrl,
              signed: false,
              onChanged: (_) => _recalc(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() => Divider(
      color: AppColors.appInk.withAlpha(25), height: 1, thickness: 1);

  // ── 純収支プレビュー ──────────────────────────────────────────────────────
  Widget _buildNetPreview() {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.appCream,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.appInk.withAlpha(15),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text('純収支プレビュー',
              style: TextStyle(
                  color:    AppColors.appInk.withAlpha(160),
                  fontSize: 14)),
          const Spacer(),
          Text(
            signedStr(_net),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _net >= 0 ? AppColors.appTeal : AppColors.appRed,
            ),
          ),
          const SizedBox(width: 4),
          Text('円',
              style: TextStyle(
                  color:    AppColors.appInk.withAlpha(160),
                  fontSize: 14)),
        ],
      ),
    );
  }

  // ── メモ ──────────────────────────────────────────────────────────────────
  Widget _buildMemo() {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.appCream,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.appInk.withAlpha(15),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _noteCtrl,
        maxLines:   4,
        decoration: InputDecoration(
          hintText: 'メモ（任意）',
          border:   InputBorder.none,
          isDense:  true,
          hintStyle: TextStyle(color: AppColors.appInk.withAlpha(100)),
        ),
      ),
    );
  }
}

// ── 着順カードウィジェット ─────────────────────────────────────────────────────
class _CountCard extends StatelessWidget {
  final int      place;
  final int      count;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onLongDecrement;
  final VoidCallback onLongIncrement;
  final VoidCallback onLongPressEnd;

  const _CountCard({
    required this.place,
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
    required this.onLongDecrement,
    required this.onLongIncrement,
    required this.onLongPressEnd,
  });

  static const _names  = ['1着', '2着', '3着', '4着'];
  static const _colors = [
    AppColors.place1,
    AppColors.place2,
    AppColors.place3,
    AppColors.place4,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[place - 1];
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.appCream,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.appInk.withAlpha(15),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(_names[place - 1],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text('$count',
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, height: 1.1)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PressBtn(
                icon:         Icons.remove,
                onTap:        onDecrement,
                onLongPress:  onLongDecrement,
                onLongPressEnd: onLongPressEnd,
              ),
              const SizedBox(width: 12),
              _PressBtn(
                icon:         Icons.add,
                onTap:        onIncrement,
                onLongPress:  onLongIncrement,
                onLongPressEnd: onLongPressEnd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PressBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onLongPressEnd;

  const _PressBtn({
    required this.icon,
    required this.onTap,
    required this.onLongPress,
    required this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:           onTap,
      onLongPress:     onLongPress,
      onLongPressEnd:  (_) => onLongPressEnd(),
      child: Container(
        width:  32,
        height: 32,
        decoration: BoxDecoration(
          color:        AppColors.appInk.withAlpha(15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: AppColors.appInk),
      ),
    );
  }
}

// ── テキスト入力行 ──────────────────────────────────────────────────────────
class _InputRow extends StatelessWidget {
  final String                  label;
  final TextEditingController   ctrl;
  final bool                    signed;
  final ValueChanged<String>    onChanged;

  const _InputRow({
    required this.label,
    required this.ctrl,
    required this.signed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.appInk.withAlpha(160), fontSize: 14)),
          const Spacer(),
          SizedBox(
            width: 120,
            child: TextField(
              controller:  ctrl,
              textAlign:   TextAlign.right,
              keyboardType: TextInputType.numberWithOptions(signed: signed),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              decoration: const InputDecoration(
                border:  InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
