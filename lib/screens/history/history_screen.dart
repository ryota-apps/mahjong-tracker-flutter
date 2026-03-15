import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/session.dart';
import '../../providers/filter_provider.dart';
import '../../providers/session_provider.dart';
import '../../utils/session_utils.dart';
import '../../widgets/filter_chip_bar.dart';
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
    final sessions = ref.watch(sessionProvider);
    final filter   = ref.watch(filterProvider);
    final filtered = applyFilter(sessions, filter, filter.withFees);

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
            child: filtered.isEmpty
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
              value: signedStr(total),
              valueColor: total >= 0 ? AppColors.appTeal : AppColors.appRed,
            ),
            _SumItem(
              label: '平均収支',
              value: signedStr(avgNet),
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
              onPressed: (_) => _confirmDelete(context, ref),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('削除しますか？'),
        content: Text('${session.shop}（${DateFormat('M/d').format(session.date)}）を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: AppColors.appRed)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      ref.read(sessionProvider.notifier).deleteSession(session.id);
    }
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
    final isFree = session.gameType == 'free';
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
                    Text(session.shop, style: shopNameStyle()),
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
                        _Badge(
                          label: isFree ? 'フリー' : 'セット',
                          color: isFree
                              ? AppColors.appTeal.withAlpha(30)
                              : AppColors.appGold.withAlpha(30),
                          textColor: isFree ? AppColors.appTeal : AppColors.appGold,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(signedStr(net),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: net >= 0 ? AppColors.appTeal : AppColors.appRed)),
                  Text('円',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.appInk.withAlpha(128))),
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
                _Badge(
                  label: 'チップ${signedStr(session.chipVal)}',
                  color: AppColors.appGold.withAlpha(30),
                  textColor: AppColors.appGold,
                ),
              if (session.venueFee != 0)
                _Badge(
                  label: '場代−${session.venueFee}',
                  color: AppColors.appRed.withAlpha(20),
                  textColor: AppColors.appRed,
                ),
              if (session.note.isNotEmpty)
                _Badge(
                  label: session.note,
                  color: AppColors.appInk.withAlpha(10),
                  textColor: AppColors.appInk.withAlpha(180),
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
  late int _c1, _c2, _c3, _c4;
  late final TextEditingController _balanceCtrl;
  late final TextEditingController _chipsCtrl;
  late final TextEditingController _chipValCtrl;
  late final TextEditingController _venueFeeCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final s  = widget.session;
    _date    = s.date;
    _shopCtrl     = TextEditingController(text: s.shop);
    _c1 = s.count1; _c2 = s.count2; _c3 = s.count3; _c4 = s.count4;
    _balanceCtrl  = TextEditingController(text: '${s.balance}');
    _chipsCtrl    = TextEditingController(text: '${s.chips}');
    _chipValCtrl  = TextEditingController(text: '${s.chipVal}');
    _venueFeeCtrl = TextEditingController(text: '${s.venueFee}');
    _noteCtrl     = TextEditingController(text: s.note);
  }

  @override
  void dispose() {
    _shopCtrl.dispose(); _balanceCtrl.dispose(); _chipsCtrl.dispose();
    _chipValCtrl.dispose(); _venueFeeCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final balance  = int.tryParse(_balanceCtrl.text)  ?? 0;
    final chips    = int.tryParse(_chipsCtrl.text)    ?? 0;
    final chipVal  = int.tryParse(_chipValCtrl.text)  ?? 0;
    final venueFee = int.tryParse(_venueFeeCtrl.text) ?? 0;
    final net = widget.session.gameType == 'free'
        ? balance + chipVal
        : balance + chipVal - venueFee;

    final updated = widget.session.copyWith(
      shop:      _shopCtrl.text.trim(),
      date:      _date,
      count1:    _c1, count2: _c2, count3: _c3, count4: _c4,
      balance:   balance,
      chips:     chips,
      chipVal:   chipVal,
      venueFee:  venueFee,
      net:       net,
      note:      _noteCtrl.text.trim(),
    );
    await ref.read(sessionProvider.notifier).updateSession(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            _EditRow(label: '店舗名',   ctrl: _shopCtrl),
            _EditRow(label: '現金収支', ctrl: _balanceCtrl, signed: true),
            _EditRow(label: 'チップ枚数', ctrl: _chipsCtrl, signed: true),
            _EditRow(label: 'チップ収支', ctrl: _chipValCtrl, signed: true),
            _EditRow(label: '場代',     ctrl: _venueFeeCtrl),
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
    );
  }
}

class _EditRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool signed;
  const _EditRow({required this.label, required this.ctrl, this.signed = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.appInk.withAlpha(160), fontSize: 13)),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: signed
                  ? const TextInputType.numberWithOptions(signed: true)
                  : TextInputType.text,
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

// ── ユーティリティ ──────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  final Color  textColor;
  const _Badge({required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: textColor)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt,
                size: 56, color: AppColors.appInk.withAlpha(60)),
            const SizedBox(height: 12),
            Text('記録がありません',
                style: TextStyle(
                    color: AppColors.appInk.withAlpha(100), fontSize: 16)),
          ],
        ),
      );
}
