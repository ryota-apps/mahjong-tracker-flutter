import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../constants/game_type.dart';
import '../../models/session.dart';
import '../../providers/filter_provider.dart';
import '../../providers/session_provider.dart';
import '../../utils/session_utils.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/info_badge.dart';
import '../../widgets/toast_widget.dart';

// ─── レート・ソートラベル ─────────────────────────────────────────────────────
const _periodLabels   = ['全期間', '今月', '先月', '直近3ヶ月'];
const _playersLabels  = ['全人数', '3人', '4人'];
const _typeLabels     = ['全種別', 'フリー', 'セット'];
const _sortLabels     = ['新しい順', '古い順', '収支高い順', '収支低い順'];

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);
    final filter       = ref.watch(filterProvider);
    final sessions     = sessionState.sessions;
    final filtered     = applyFilter(sessions, filter, filter.withFees);

    return Scaffold(
      appBar: AppBar(title: const Text('戦績一覧')),
      body: Column(
        children: [
          // フィルターバー
          _FilterBar(sessions: sessions),
          // サマリーバー
          if (filtered.isNotEmpty) _SummaryBar(sessions: filtered, withFees: filter.withFees),
          // リスト
          Expanded(
            child: sessionState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _SessionTile(session: filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── フィルターバー ──────────────────────────────────────────────────────────
class _FilterBar extends ConsumerWidget {
  final List<Session> sessions;
  const _FilterBar({required this.sessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f   = ref.watch(filterProvider);
    final ntf = ref.read(filterProvider.notifier);

    final shopNames = sessions.map((s) => s.shop).toSet().toList()..sort();
    final rates     = sessions.map((s) => s.rule).toSet().toList()..sort();

    return FilterChipBar(
      children: [
        // 期間
        ..._periodLabels.asMap().entries.map((e) => AppFilterChip(
          label:    e.value,
          selected: f.period.index == e.key,
          onTap: () => ntf.update((s) => s.copyWith(period: PeriodFilter.values[e.key])),
        )),
        const FilterBarDivider(),
        // 人数
        ..._playersLabels.asMap().entries.map((e) => AppFilterChip(
          label:    e.value,
          selected: f.players.index == e.key,
          onTap: () => ntf.update((s) => s.copyWith(players: PlayersFilter.values[e.key])),
        )),
        const FilterBarDivider(),
        // 種別
        ..._typeLabels.asMap().entries.map((e) => AppFilterChip(
          label:    e.value,
          selected: f.gameType.index == e.key,
          onTap: () => ntf.update((s) => s.copyWith(gameType: GameTypeFilter.values[e.key])),
        )),
        const FilterBarDivider(),
        // 店舗
        AppFilterChip(
          label:    '全店舗',
          selected: f.shopId == null,
          onTap: () => ntf.update((s) => s.copyWith(clearShopId: true)),
        ),
        ...shopNames.map((n) => AppFilterChip(
          label:    n,
          selected: f.shopId == n,
          onTap: () => ntf.update((s) => s.copyWith(shopId: n)),
        )),
        const FilterBarDivider(),
        // レート
        AppFilterChip(
          label:    '全レート',
          selected: f.rate == null,
          onTap: () => ntf.update((s) => s.copyWith(clearRate: true)),
        ),
        ...rates.map((r) => AppFilterChip(
          label:    r == 0 ? '未設定' : '${r}pt',
          selected: f.rate == r,
          onTap: () => ntf.update((s) => s.copyWith(rate: r)),
        )),
        const FilterBarDivider(),
        // ゲーム代差し引く
        AppFilterChip(
          label:    'ゲーム代差引',
          selected: !f.withFees,
          onTap: () => ntf.update((s) => s.copyWith(withFees: !f.withFees)),
        ),
        const FilterBarDivider(),
        // ソート
        ..._sortLabels.asMap().entries.map((e) => AppFilterChip(
          label:    e.value,
          selected: f.sortOrder.index == e.key,
          onTap: () => ntf.update((s) => s.copyWith(sortOrder: SortOrder.values[e.key])),
        )),
      ],
    );
  }
}

// ── サマリーバー ──────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<Session> sessions;
  final bool withFees;
  const _SummaryBar({required this.sessions, required this.withFees});

  @override
  Widget build(BuildContext context) {
    final total = sessions.fold(0, (s, e) => s + getNet(e, withFees));
    final totalGames = sessions.fold(0, (s, e) => s + e.totalGames);
    final avgNet  = sessions.isEmpty ? 0 : (total / sessions.length).round();
    final counts  = [
      sessions.fold(0, (s, e) => s + e.count1),
      sessions.fold(0, (s, e) => s + e.count2),
      sessions.fold(0, (s, e) => s + e.count3),
      sessions.fold(0, (s, e) => s + e.count4),
    ];
    final avgPlace = totalGames == 0
        ? 0.0
        : sessions.fold(
                0.0,
                (s, e) =>
                    s +
                    (e.count1 * 1.0 +
                        e.count2 * 2.0 +
                        e.count3 * 3.0 +
                        e.count4 * 4.0)) /
            totalGames;
    final placeColors = [
      AppColors.place1, AppColors.place2, AppColors.place3, AppColors.place4
    ];

    return Container(
      color: AppColors.appCream,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _SumItem(label: 'セッション', value: '${sessions.length}回'),
            _SumItem(label: '総ゲーム',   value: '$totalGames局'),
            _SumItem(label: '平均着順',   value: avgPlace.toStringAsFixed(2)),
            // 着順内訳
            Row(
              children: List.generate(counts.length, (i) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: placeColors[i], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 3),
                    Text('${counts[i]}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )),
            ),
            _SumItem(
              label: '収支合計',
              value: signedYen(total),
              valueColor: total >= 0 ? AppColors.appTeal : AppColors.appRed,
            ),
            _SumItem(
              label: '平均収支',
              value: signedYen(avgNet),
              valueColor: avgNet >= 0 ? AppColors.appTeal : AppColors.appRed,
            ),
          ],
        ),
      ),
    );
  }
}

class _SumItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SumItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: AppColors.appInk.withAlpha(128))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? AppColors.appInk)),
        ],
      ),
    );
  }
}

// ── セッションタイル（スライダブル） ─────────────────────────────────────────
class _SessionTile extends ConsumerWidget {
  final Session session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final withFees = ref.watch(filterProvider).withFees;
    final net = getNet(session, withFees);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: Key(session.id),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.22,
          children: [
            SlidableAction(
              onPressed: (_) => _duplicate(context, ref),
              backgroundColor: AppColors.appGold,
              foregroundColor: Colors.white,
              icon: Icons.copy,
              label: '複製',
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.55,
          children: [
            SlidableAction(
              onPressed: (_) => _duplicate(context, ref),
              backgroundColor: AppColors.appGold,
              foregroundColor: Colors.white,
              icon: Icons.copy,
              label: '複製',
            ),
            SlidableAction(
              onPressed: (_) => _edit(context, ref),
              backgroundColor: AppColors.appTeal,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: '編集',
            ),
            SlidableAction(
              onPressed: (_) => _delete(context, ref),
              backgroundColor: AppColors.appRed,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: '削除',
            ),
          ],
        ),
        child: _SessionCard(session: session, net: net),
      ),
    );
  }

  void _duplicate(BuildContext context, WidgetRef ref) {
    final copy = session.copyWith(id: null, createdAt: DateTime.now());
    ref.read(sessionProvider.notifier).addSession(copy);
    showToast(context, '複製しました');
  }

  void _edit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context:     context,
      isScrollControlled: true,
      builder:     (_) => _EditSheet(session: session),
    );
  }

  void _delete(BuildContext context, WidgetRef ref) {
    ref.read(sessionProvider.notifier).deleteSession(session.id);
  }
}

// ── セッションカード本体 ──────────────────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final Session session;
  final int     net;
  const _SessionCard({required this.session, required this.net});

  static const _placeColors = [
    AppColors.place1, AppColors.place2, AppColors.place3, AppColors.place4,
  ];
  static const _placeNames = ['1着', '2着', '3着', '4着'];

  @override
  Widget build(BuildContext context) {
    final isFree = session.gameType == GameType.free;
    final counts = [session.count1, session.count2, session.count3, session.count4];

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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 上段: 店舗名 + 純収支 ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.shop.isEmpty ? '店舗未設定' : session.shop,
                        style: GoogleFonts.notoSerif(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.appInk,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('yyyy/M/d (E)', 'ja').format(session.date)}  '
                      '${session.players}人  ${session.format}  '
                      '${session.rule > 0 ? "${session.rule}pt" : ""}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.appInk.withAlpha(160)),
                    ),
                    const SizedBox(height: 4),
                    // バッジ行
                    Wrap(
                      spacing: 4,
                      children: [
                        InfoBadge(
                          text:  isFree ? 'フリー' : 'セット',
                          color: isFree ? AppColors.appTeal : AppColors.appGold,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(signedCommaStr(net),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: net >= 0 ? AppColors.appTeal : AppColors.appRed)),
                  Text('円',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.appInk.withAlpha(191))),
                ],
              ),
            ],
          ),
          Divider(color: AppColors.appInk.withAlpha(20), height: 12),
          // ── 着順カウント ─────────────────────────────────────────────────
          Row(
            children: [
              ...List.generate(session.players, (i) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                          color:  _placeColors[i],
                          shape:  BoxShape.circle),
                    ),
                    const SizedBox(width: 3),
                    Text(_placeNames[i],
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 2),
                    Text('${counts[i]}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
              const Spacer(),
              Text('計${session.totalGames}局',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.appInk.withAlpha(128))),
            ],
          ),
          // ── チップ・場代・メモ ───────────────────────────────────────────
          if (session.chipVal != 0 || session.venueFee != 0 || session.note.isNotEmpty)
            const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (session.chipVal != 0)
                InfoBadge(
                  text:  'チップ${signedCommaStr(session.chipVal)}',
                  color: AppColors.appGold,
                ),
              if (session.venueFee != 0)
                InfoBadge(
                  text:  '場代 ${formatYen(session.venueFee)}',
                  color: AppColors.appRed,
                ),
              if (session.note.isNotEmpty)
                InfoBadge(
                  text:  session.note,
                  color: AppColors.appInk,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 編集シート ──────────────────────────────────────────────────────────────
class _EditSheet extends ConsumerStatefulWidget {
  final Session session;
  const _EditSheet({required this.session});

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late DateTime _date;
  late final TextEditingController _shopCtrl;
  late int  _c1, _c2, _c3, _c4;
  bool      _balanceNeg = false;
  bool      _isChipNeg  = false;
  late final TextEditingController _balanceCtrl;
  late final TextEditingController _chipsCtrl;
  // chipVal は chips × chipUnit で自動計算（手入力廃止）
  late final TextEditingController _venueFeeCtrl;
  late final TextEditingController _gameFeeCtrl;
  late final TextEditingController _topPrizeCtrl;
  late final TextEditingController _noteCtrl;

  int get _chipUnit => widget.session.chipUnit;
  int get _signedChips =>
      (_isChipNeg ? -1 : 1) * (int.tryParse(_chipsCtrl.text) ?? 0);
  int get _autoChipVal => _signedChips * _chipUnit;

  @override
  void initState() {
    super.initState();
    final s  = widget.session;
    _date    = s.date;
    _shopCtrl     = TextEditingController(text: s.shop);
    _c1 = s.count1; _c2 = s.count2; _c3 = s.count3; _c4 = s.count4;
    _balanceNeg   = s.balance < 0;
    _isChipNeg    = s.chips < 0;
    _balanceCtrl  = TextEditingController(text: '${s.balance.abs()}');
    _chipsCtrl    = TextEditingController(text: '${s.chips.abs()}');
    _venueFeeCtrl = TextEditingController(text: '${s.venueFee}');
    _gameFeeCtrl  = TextEditingController(text: s.gameFee  > 0 ? '${s.gameFee}'  : '');
    _topPrizeCtrl = TextEditingController(text: s.topPrize > 0 ? '${s.topPrize}' : '');
    _noteCtrl     = TextEditingController(text: s.note);
    // chips 変更時に再描画して自動計算値を反映
    _chipsCtrl.addListener(() => setState(() {}));
  }

  static const _placeNames  = ['1着', '2着', '3着', '4着'];
  static const _placeColors = [
    AppColors.place1, AppColors.place2, AppColors.place3, AppColors.place4,
  ];

  int _countOf(int i) {
    switch (i) {
      case 0: return _c1;
      case 1: return _c2;
      case 2: return _c3;
      default: return _c4;
    }
  }

  void _setCount(int i, int v) {
    setState(() {
      switch (i) {
        case 0: _c1 = v.clamp(0, 999);
        case 1: _c2 = v.clamp(0, 999);
        case 2: _c3 = v.clamp(0, 999);
        case 3: _c4 = v.clamp(0, 999);
      }
    });
  }

  @override
  void dispose() {
    _shopCtrl.dispose(); _balanceCtrl.dispose(); _chipsCtrl.dispose();
    _venueFeeCtrl.dispose();
    _gameFeeCtrl.dispose(); _topPrizeCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rawBalance = int.tryParse(_balanceCtrl.text) ?? 0;
    final balance  = _balanceNeg ? -rawBalance : rawBalance;
    final chips    = _signedChips;
    final chipVal  = _autoChipVal;
    final venueFee = int.tryParse(_venueFeeCtrl.text) ?? 0;
    final gameFee  = int.tryParse(_gameFeeCtrl.text)  ?? widget.session.gameFee;
    final topPrize = int.tryParse(_topPrizeCtrl.text) ?? widget.session.topPrize;
    final totalGames = _c1 + _c2 + _c3 + _c4;

    // session_utils.getNet() と整合した計算
    final int net;
    if (widget.session.gameType == GameType.free) {
      net = balance + chipVal
          - (totalGames * gameFee)
          - (_c1 * topPrize);
    } else {
      net = balance + chipVal - venueFee;
    }

    final updated = widget.session.copyWith(
      shop:      _shopCtrl.text.trim(),
      date:      _date,
      count1:    _c1, count2: _c2, count3: _c3, count4: _c4,
      balance:   balance,
      chips:     chips,
      chipVal:   chipVal,
      venueFee:  venueFee,
      gameFee:   gameFee,
      topPrize:  topPrize,
      net:       net,
      note:      _noteCtrl.text.trim(),
    );
    await ref.read(sessionProvider.notifier).updateSession(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.appPaper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.appInk.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('セッション編集',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // ── 着順カウント ────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text('着順カウント',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.appInk.withAlpha(128),
                      letterSpacing: 0.4)),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(widget.session.players, (i) {
                return Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                  color: _placeColors[i],
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 3),
                          Text(_placeNames[i],
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SmallCountBtn(
                            icon:  Icons.remove,
                            onTap: () => _setCount(i, _countOf(i) - 1),
                          ),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${_countOf(i)}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          _SmallCountBtn(
                            icon:  Icons.add,
                            onTap: () => _setCount(i, _countOf(i) + 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.appInk.withAlpha(20), height: 1),
            const SizedBox(height: 4),
            // ── テキスト入力 ─────────────────────────────────────────────
            _EditRow(label: '店舗名', ctrl: _shopCtrl),
            // ── 現金収支（+/− トグル）──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text('現金収支',
                        style: TextStyle(
                            color: AppColors.appInk.withAlpha(191),
                            fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _balanceNeg = !_balanceNeg),
                    child: Container(
                      width:  36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _balanceNeg
                            ? AppColors.appRed
                            : AppColors.appTeal,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          _balanceNeg ? '−' : '＋',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller:   _balanceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        border:  UnderlineInputBorder(),
                        hintText: '0',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // チップ枚数（+/− トグル付き）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text('チップ枚数',
                        style: TextStyle(
                            color: AppColors.appInk.withAlpha(160),
                            fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isChipNeg = !_isChipNeg),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _isChipNeg
                            ? AppColors.appRed
                            : AppColors.appTeal,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          _isChipNeg ? '−' : '＋',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _chipsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        border: UnderlineInputBorder(),
                        hintText: '0',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // チップ収支は chipUnit > 0 のとき自動計算して読み取り専用表示
            if (_chipUnit > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text('チップ収支',
                          style: TextStyle(
                              color: AppColors.appInk.withAlpha(160),
                              fontSize: 13)),
                    ),
                    Expanded(
                      child: Text(
                        signedCommaStr(_autoChipVal),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _autoChipVal >= 0
                              ? AppColors.appTeal
                              : AppColors.appRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _EditRow(label: '場代',     ctrl: _venueFeeCtrl),
            if (widget.session.gameType == GameType.free) ...[
              _EditRow(label: 'ゲーム代/局', ctrl: _gameFeeCtrl,  keyboard: TextInputType.number),
              _EditRow(label: 'トップ賞/回', ctrl: _topPrizeCtrl, keyboard: TextInputType.number),
            ],
            _EditRow(label: 'メモ',     ctrl: _noteCtrl),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.appTeal),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType? keyboard;
  const _EditRow({
    required this.label,
    required this.ctrl,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardType = keyboard ?? TextInputType.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.appInk.withAlpha(160), fontSize: 13)),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: keyboardType,
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filterProvider);
    final isFiltered = f.period != PeriodFilter.all ||
        f.players != PlayersFilter.all ||
        f.gameType != GameTypeFilter.all ||
        f.shopId != null ||
        f.rate != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 56, color: AppColors.appInk.withAlpha(60)),
          const SizedBox(height: 12),
          Text(
            isFiltered ? 'フィルターに一致する記録がありません' : '記録がありません',
            style: TextStyle(color: AppColors.appInk.withAlpha(100), fontSize: 16),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.read(filterProvider.notifier).reset(),
              child: const Text('フィルターをリセット'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallCountBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _SmallCountBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  30,
        height: 30,
        decoration: BoxDecoration(
          color:        AppColors.appInk.withAlpha(15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppColors.appInk),
      ),
    );
  }
}
