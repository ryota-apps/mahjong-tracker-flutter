import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../constants/game_type.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../../utils/session_utils.dart';
import '../../widgets/toast_widget.dart';

const _kDraft = 'session_draft';

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
  final Map<String, dynamic>? draft;

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
    this.draft,
  });

  @override
  ConsumerState<SessionInputScreen> createState() => _SessionInputScreenState();
}

class _SessionInputScreenState extends ConsumerState<SessionInputScreen> {
  late int _chipUnit;
  bool     _balanceNeg  = false;
  bool     _isChipNeg   = false;

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
    _chipUnit = widget.chipUnit;

    if (widget.draft != null) {
      final d      = widget.draft!;
      final counts = (d['counts'] as Map<String, dynamic>?) ?? {};
      _c1          = (counts['1'] as int?) ?? 0;
      _c2          = (counts['2'] as int?) ?? 0;
      _c3          = (counts['3'] as int?) ?? 0;
      _c4          = (counts['4'] as int?) ?? 0;
      _balanceNeg   = (d['balanceNeg']  as bool?) ?? false;
      _isChipNeg    = (d['isChipNeg']   as bool?) ?? false;
      _balanceCtrl  = TextEditingController(text: (d['balance']        as String?) ?? '');
      _chipsCtrl    = TextEditingController(text: (d['chips']          as String?) ?? '');
      _chipUnitCtrl = TextEditingController(text: (d['chipUnitManual'] as String?) ?? '$_chipUnit');
      _venueFeeCtrl = TextEditingController(text: (d['venueFee']       as String?) ?? '');
      _noteCtrl     = TextEditingController(text: (d['note']           as String?) ?? '');
    } else {
      _balanceCtrl  = TextEditingController();
      _chipsCtrl    = TextEditingController();
      _chipUnitCtrl = TextEditingController(text: '$_chipUnit');
      _venueFeeCtrl = TextEditingController();
      _noteCtrl     = TextEditingController();
    }

    // 初期値を計算（setState不使用）
    final rawBalance = int.tryParse(_balanceCtrl.text) ?? 0;
    _balance  = _balanceNeg ? -rawBalance : rawBalance;
    _chips    = int.tryParse(_chipsCtrl.text)    ?? 0;
    _chipUnit = int.tryParse(_chipUnitCtrl.text) ?? _chipUnit;
    _venueFee = int.tryParse(_venueFeeCtrl.text) ?? 0;
    _chipVal  = _chips * _chipUnit;
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

  // ── ドラフト保存 ──────────────────────────────────────────────────────────
  Future<void> _saveDraft() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDraft, jsonEncode({
      'counts':        {'1': _c1, '2': _c2, '3': _c3, '4': _c4},
      'balance':       _balanceCtrl.text,
      'balanceNeg':    _balanceNeg,
      'chips':         _chipsCtrl.text,
      'isChipNeg':     _isChipNeg,
      'chipUnitManual': _chipUnitCtrl.text,
      'venueFee':      _venueFeeCtrl.text,
      'note':          _noteCtrl.text,
    }));
  }

  Future<void> _clearDraft() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kDraft);
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
    _saveDraft();
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
    final rawBalance = int.tryParse(_balanceCtrl.text) ?? 0;
    _balance  = _balanceNeg ? -rawBalance : rawBalance;
    final rawChips = int.tryParse(_chipsCtrl.text) ?? 0;
    _chips    = _isChipNeg ? -rawChips : rawChips;
    _chipUnit = int.tryParse(_chipUnitCtrl.text) ?? 0;
    _venueFee = int.tryParse(_venueFeeCtrl.text) ?? 0;
    _chipVal  = _chips * _chipUnit;
    setState(() {});
    _saveDraft();
  }

  int get _net {
    if (widget.gameType == GameType.free) return _balance + _chipVal;
    return _balance + _chipVal - _venueFee;
  }

  // ── 保存 ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    _recalc();
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
      shop:     widget.shopName,
      date:     widget.date,
      players:  widget.players,
      format:   widget.format,
      rule:     widget.rule,
      gameType: widget.gameType,
      count1:   _c1,
      count2:   _c2,
      count3:   _c3,
      count4:   widget.players == 4 ? _c4 : 0,
      balance:  _balance,
      chips:    _chips,
      chipUnit: _chipUnit,
      chipVal:  _chipVal,
      venueFee: _venueFee,
      net:      _net,
      gameFee:  widget.gameFee,
      topPrize: widget.topPrize,
      note:     _noteCtrl.text.trim(),
    );

    await ref.read(sessionProvider.notifier).addSession(session);
    await _clearDraft();

    if (!mounted) return;
    final sessions   = ref.read(sessionProvider).sessions;
    final todayTotal = todayNetTotal(sessions);
    Navigator.of(context).pop();
    showToast(context, '保存しました　今日: ${signedYen(todayTotal)}');
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
    final confirmed = result ?? false;
    if (confirmed) await _clearDraft();
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final isFree   = widget.gameType == GameType.free;
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
                style: TextStyle(fontSize: 12, color: AppColors.appInk.withAlpha(191)),
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStickyNetBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCountGrid(),
                    const SizedBox(height: 16),
                    _buildBalanceSection(isFree: isFree, showChip: showChip),
                    const SizedBox(height: 16),
                    _buildMemo(),
                    const SizedBox(height: 24),
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
          ],
        ),
      ),
    );
  }

  // ── 純収支 Sticky バー ────────────────────────────────────────────────────
  Widget _buildStickyNetBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.appCream,
        border: Border(
          bottom: BorderSide(color: AppColors.appInk.withAlpha(51), width: 1),
        ),
      ),
      child: Column(
        children: [
          Text('純収支',
              style: TextStyle(
                  fontSize: 11, color: AppColors.appInk.withAlpha(153))),
          Text(
            signedYen(_net),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _net >= 0 ? AppColors.appTeal : AppColors.appRed,
            ),
          ),
        ],
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
        place:           p,
        count:           _countOf(p),
        onDecrement:     () => _updateCount(p, -1),
        onIncrement:     () => _updateCount(p, 1),
        onLongDecrement: () => _startLongPress(p, -1),
        onLongIncrement: () => _startLongPress(p, 1),
        onLongPressEnd:  _stopLongPress,
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
          _BalanceRow(
            label:        isFree ? '現金収支' : '点棒収支',
            ctrl:         _balanceCtrl,
            isNegative:   _balanceNeg,
            onToggleSign: () {
              setState(() => _balanceNeg = !_balanceNeg);
              _recalc();
            },
            onChanged: (_) => _recalc(),
          ),
          if (showChip) ...[
            _divider(),
            _BalanceRow(
              label:        'チップ枚数',
              ctrl:         _chipsCtrl,
              isNegative:   _isChipNeg,
              onToggleSign: () {
                setState(() => _isChipNeg = !_isChipNeg);
                _recalc();
              },
              onChanged: (_) => _recalc(),
            ),
          ],
          if (!isFree) ...[
            _divider(),
            _InputRow(
              label:     'チップ単価',
              ctrl:      _chipUnitCtrl,
              signed:    false,
              onChanged: (_) => _recalc(),
            ),
          ],
          if (showChip) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text('チップ収支',
                      style: TextStyle(
                          color: AppColors.appInk.withAlpha(204), fontSize: 14)),
                  const Spacer(),
                  Text(signedCommaStr(_chipVal),
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
              label:     '場代',
              ctrl:      _venueFeeCtrl,
              signed:    false,
              onChanged: (_) => _recalc(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() => Divider(
      color: AppColors.appInk.withAlpha(51), height: 1, thickness: 1);

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
        onChanged: (_) => _saveDraft(),
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
                icon:            Icons.remove,
                onTap:           onDecrement,
                onLongPress:     onLongDecrement,
                onLongPressEnd:  onLongPressEnd,
              ),
              const SizedBox(width: 12),
              _PressBtn(
                icon:            Icons.add,
                onTap:           onIncrement,
                onLongPress:     onLongIncrement,
                onLongPressEnd:  onLongPressEnd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PressBtn extends StatefulWidget {
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
  State<_PressBtn> createState() => _PressBtnState();
}

class _PressBtnState extends State<_PressBtn> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: () {
        setState(() => _pressing = true);
        widget.onLongPress();
      },
      onLongPressEnd: (_) {
        setState(() => _pressing = false);
        widget.onLongPressEnd();
      },
      child: AnimatedOpacity(
        opacity:  _pressing ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width:  44,
          height: 44,
          decoration: BoxDecoration(
            color:        AppColors.appInk.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 20, color: AppColors.appInk),
        ),
      ),
    );
  }
}

// ── +/− 符号トグル付き入力行 ─────────────────────────────────────────────────
class _BalanceRow extends StatelessWidget {
  final String                label;
  final TextEditingController ctrl;
  final bool                  isNegative;
  final VoidCallback          onToggleSign;
  final ValueChanged<String>  onChanged;

  const _BalanceRow({
    required this.label,
    required this.ctrl,
    required this.isNegative,
    required this.onToggleSign,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.appInk.withAlpha(204), fontSize: 14)),
          const Spacer(),
          // +/− トグルボタン
          GestureDetector(
            onTap: onToggleSign,
            child: Container(
              width:  44,
              height: 44,
              decoration: BoxDecoration(
                color:        isNegative ? AppColors.appRed : AppColors.appTeal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  isNegative ? '−' : '＋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextField(
              controller:   ctrl,
              textAlign:    TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText:         '0',
                hintStyle: TextStyle(color: AppColors.appInk.withAlpha(77)),
                contentPadding:   const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: AppColors.appInk.withAlpha(77), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.appInk, width: 2),
                ),
                filled:    true,
                fillColor: AppColors.appPaper,
              ),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w500),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 通常テキスト入力行 ──────────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.appInk.withAlpha(204), fontSize: 14)),
          const Spacer(),
          SizedBox(
            width: 120,
            child: TextField(
              controller:   ctrl,
              textAlign:    TextAlign.right,
              keyboardType: TextInputType.numberWithOptions(signed: signed),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              decoration: InputDecoration(
                hintText:       '0',
                hintStyle: TextStyle(color: AppColors.appInk.withAlpha(77)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: AppColors.appInk.withAlpha(77), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.appInk, width: 2),
                ),
                filled:    true,
                fillColor: AppColors.appPaper,
              ),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w500),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
