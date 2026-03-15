import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../models/session.dart';
import '../../providers/filter_provider.dart';
import '../../providers/session_provider.dart';
import '../../utils/session_utils.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/info_badge.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);
    final filter       = ref.watch(filterProvider);
    final all          = sessionState.sessions;
    final data         = applyFilter(all, filter, filter.withFees);
    // 分析は古い順に並べ直す
    final sorted = [...data]..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(title: const Text('分析')),
      body: Column(
        children: [
          _FilterBar(sessions: all),
          Expanded(
            child: sessionState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                ? const _EmptyState()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _CumulativeChart(sessions: sorted, withFees: filter.withFees),
                      const SizedBox(height: 16),
                      _SummaryCards(sessions: data, withFees: filter.withFees),
                      const SizedBox(height: 16),
                      _MonthlyChart(sessions: sorted, withFees: filter.withFees),
                      const SizedBox(height: 16),
                      _AverageRankCard(sessions: data),
                      const SizedBox(height: 16),
                      _RankDistribution(sessions: data),
                      const SizedBox(height: 16),
                      _ShopStats(sessions: data, withFees: filter.withFees),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── フィルターバー（戦績一覧と共通デザイン）────────────────────────────────
class _FilterBar extends ConsumerWidget {
  final List<Session> sessions;
  const _FilterBar({required this.sessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f   = ref.watch(filterProvider);
    final ntf = ref.read(filterProvider.notifier);
    const periodLabels = ['全期間', '今月', '先月', '直近3ヶ月'];

    return FilterChipBar(
      children: [
        ...periodLabels.asMap().entries.map((e) => AppFilterChip(
          label:    e.value,
          selected: f.period.index == e.key,
          onTap: () => ntf.update((s) => s.copyWith(
              period: PeriodFilter.values[e.key])),
        )),
        const FilterBarDivider(),
        AppFilterChip(
          label: '全人数', selected: f.players == PlayersFilter.all,
          onTap: () => ntf.update((s) => s.copyWith(players: PlayersFilter.all)),
        ),
        AppFilterChip(
          label: '3人', selected: f.players == PlayersFilter.three,
          onTap: () => ntf.update((s) => s.copyWith(players: PlayersFilter.three)),
        ),
        AppFilterChip(
          label: '4人', selected: f.players == PlayersFilter.four,
          onTap: () => ntf.update((s) => s.copyWith(players: PlayersFilter.four)),
        ),
        const FilterBarDivider(),
        AppFilterChip(
          label: 'ゲーム代差引', selected: !f.withFees,
          onTap: () => ntf.update((s) => s.copyWith(withFees: !f.withFees)),
        ),
      ],
    );
  }
}

// ── セクション1: 累計純収支グラフ ──────────────────────────────────────────
class _CumulativeChart extends StatelessWidget {
  final List<Session> sessions;
  final bool withFees;
  const _CumulativeChart({required this.sessions, required this.withFees});

  @override
  Widget build(BuildContext context) {
    // 全期間の場合は直近30件のみ
    final disp = sessions.length > 30 ? sessions.sublist(sessions.length - 30) : sessions;

    double cumulative = 0;
    final spots = disp.asMap().entries.map((e) {
      cumulative += getNet(e.value, withFees);
      return FlSpot(e.key.toDouble(), cumulative);
    }).toList();

    if (spots.isEmpty) return const SizedBox.shrink();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final rangeY = (maxY - minY).abs();
    final paddedMax = maxY + rangeY * 0.15;
    final paddedMin = minY - rangeY * 0.15;

    return _AnalysisCard(
      title: '累計純収支の推移',
      child: RepaintBoundary(
        child: SizedBox(
          height: 200,
          child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (spots.length - 1).toDouble(),
            minY: paddedMin,
            maxY: paddedMax,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: AppColors.appInk.withAlpha(190),
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 3,
                    color: spot.y >= 0 ? AppColors.appTeal : AppColors.appRed,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.appTeal.withAlpha(50),
                  cutOffY: 0,
                  applyCutOffY: true,
                ),
                aboveBarData: BarAreaData(
                  show: true,
                  color: AppColors.appRed.withAlpha(50),
                  cutOffY: 0,
                  applyCutOffY: true,
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.appInk.withAlpha(217),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final idx = spot.x.toInt();
                    if (idx < 0 || idx >= disp.length) return null;
                    final s   = disp[idx];
                    final net = getNet(s, withFees);
                    return LineTooltipItem(
                      '${DateFormat('M/d').format(s.date)} ${s.shop}\n',
                      const TextStyle(color: Colors.white, fontSize: 11),
                      children: [
                        TextSpan(
                          text: signedYen(net),
                          style: TextStyle(
                            color: net >= 0 ? AppColors.appTeal : AppColors.appRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
              touchCallback: (event, response) {
                if (event is! FlTapUpEvent) return;
                final spot = response?.lineBarSpots?.firstOrNull;
                if (spot == null) return;
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= disp.length) return;
                showModalBottomSheet(
                  context: context,
                  builder: (_) => _SessionDetailSheet(
                    session: disp[idx],
                    net:     getNet(disp[idx], withFees),
                  ),
                );
              },
            ),
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (y) => FlLine(
                color: y == 0
                    ? AppColors.appInk.withAlpha(100)
                    : AppColors.appInk.withAlpha(20),
                strokeWidth: y == 0 ? 1.5 : 0.5,
                dashArray: y == 0 ? [4, 4] : null,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (spots.length / 5).ceilToDouble().clamp(1, double.infinity),
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= disp.length) return const SizedBox.shrink();
                    return Text(
                      DateFormat('M/d').format(disp[idx].date),
                      style: const TextStyle(fontSize: 9),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, _) => Text(
                    signedKStr(v.toInt()),
                    style: const TextStyle(fontSize: 9),
                  ),
                ),
              ),
              rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    ));
  }
}

// ── セクション2: 収支サマリーカード ─────────────────────────────────────────
class _SummaryCards extends StatelessWidget {
  final List<Session> sessions;
  final bool withFees;
  const _SummaryCards({required this.sessions, required this.withFees});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    final nets     = sessions.map((s) => getNet(s, withFees)).toList();
    final total    = nets.fold(0, (a, b) => a + b);
    final avg      = (total / sessions.length).round();
    final best     = nets.reduce((a, b) => a > b ? a : b);
    final worst    = nets.reduce((a, b) => a < b ? a : b);
    final chipTotal= sessions.fold(0, (s, e) => s + e.chipVal);

    return _AnalysisCard(
      title: '収支サマリー',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StatBox(label: '累計純収支', value: signedCommaStr(total),
              color: total >= 0 ? AppColors.appTeal : AppColors.appRed),
          _StatBox(label: '平均/セッション', value: signedCommaStr(avg),
              color: avg >= 0 ? AppColors.appTeal : AppColors.appRed),
          _StatBox(label: '最高',  value: signedCommaStr(best),  color: AppColors.appTeal),
          _StatBox(label: '最低',  value: signedCommaStr(worst), color: AppColors.appRed),
          if (chipTotal != 0)
            _StatBox(label: '累計チップ', value: signedCommaStr(chipTotal),
                color: AppColors.appGold),
          _StatBox(label: 'セッション数', value: '${sessions.length}回',
              color: AppColors.appInk),
        ],
      ),
    );
  }
}

// ── セクション3: 月別収支 ────────────────────────────────────────────────────
class _MonthlyChart extends StatelessWidget {
  final List<Session> sessions;
  final bool withFees;
  const _MonthlyChart({required this.sessions, required this.withFees});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(
        6, (i) => DateTime(now.year, now.month - (5 - i)));

    final monthlyNets = months.map((m) {
      return sessions
          .where((s) => s.date.year == m.year && s.date.month == m.month)
          .fold(0, (sum, s) => sum + getNet(s, withFees));
    }).toList();

    final barGroups = List.generate(months.length, (i) {
      final net = monthlyNets[i];
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY:   net.toDouble(),
            fromY: 0,
            color: net >= 0
                ? AppColors.appTealLight.withAlpha(200)
                : AppColors.appRed.withAlpha(200),
            width: 18,
            borderRadius: net >= 0
                ? const BorderRadius.vertical(top: Radius.circular(4))
                : const BorderRadius.vertical(bottom: Radius.circular(4)),
          ),
        ],
      );
    });

    final allNets = monthlyNets.where((v) => v != 0);
    final maxY = allNets.isEmpty ? 1000.0 : allNets.reduce((a, b) => a > b ? a : b).toDouble();
    final minY = allNets.isEmpty ? -1000.0 : allNets.reduce((a, b) => a < b ? a : b).toDouble();

    return _AnalysisCard(
      title: '月別収支（直近6ヶ月）',
      child: RepaintBoundary(
        child: SizedBox(
          height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY + maxY.abs() * 0.2,
            minY: minY - minY.abs() * 0.2,
            barGroups: barGroups,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (y) => FlLine(
                color: y == 0
                    ? AppColors.appInk.withAlpha(100)
                    : AppColors.appInk.withAlpha(20),
                strokeWidth: y == 0 ? 1.5 : 0.5,
                dashArray: y == 0 ? [4, 4] : null,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= months.length) return const SizedBox.shrink();
                    return Text(
                      DateFormat('M月').format(months[i]),
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, _) => Text(
                    signedKStr(v.toInt()),
                    style: const TextStyle(fontSize: 9),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    ));
  }
}

// ── セクション4: 平均着順 ─────────────────────────────────────────────────
class _AverageRankCard extends StatelessWidget {
  final List<Session> sessions;
  const _AverageRankCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    double calcAvg(Iterable<Session> list) {
      final total = list.fold(0, (s, e) => s + e.totalGames);
      if (total == 0) return 0;
      return list.fold(
              0.0,
              (s, e) =>
                  s + e.count1 * 1.0 + e.count2 * 2.0 +
                  e.count3 * 3.0 + e.count4 * 4.0) /
          total;
    }

    final four  = sessions.where((s) => s.players == 4).toList();
    final three = sessions.where((s) => s.players == 3).toList();

    return _AnalysisCard(
      title: '平均着順',
      child: Row(
        children: [
          Expanded(child: _AvgBox(
            label:  '四麻',
            avg:    calcAvg(four),
            games:  four.fold(0, (s, e) => s + e.totalGames),
          )),
          const SizedBox(width: 12),
          Expanded(child: _AvgBox(
            label:  '三麻',
            avg:    calcAvg(three),
            games:  three.fold(0, (s, e) => s + e.totalGames),
          )),
        ],
      ),
    );
  }
}

class _AvgBox extends StatelessWidget {
  final String label;
  final double avg;
  final int    games;
  const _AvgBox({required this.label, required this.avg, required this.games});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.appInk.withAlpha(8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: AppColors.appInk.withAlpha(128))),
          const SizedBox(height: 4),
          Text(
            games == 0 ? '—' : avg.toStringAsFixed(2),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text('$games局', style: TextStyle(fontSize: 11, color: AppColors.appInk.withAlpha(128))),
        ],
      ),
    );
  }
}

// ── セクション5: 着順分布 ─────────────────────────────────────────────────
class _RankDistribution extends StatelessWidget {
  final List<Session> sessions;
  const _RankDistribution({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final four  = sessions.where((s) => s.players == 4).toList();
    final three = sessions.where((s) => s.players == 3).toList();

    return _AnalysisCard(
      title: '着順分布',
      child: Column(
        children: [
          if (four.isNotEmpty)
            _DistRow(label: '四麻', sessions: four, maxPlaces: 4),
          if (four.isNotEmpty && three.isNotEmpty) const SizedBox(height: 12),
          if (three.isNotEmpty)
            _DistRow(label: '三麻', sessions: three, maxPlaces: 3),
        ],
      ),
    );
  }
}

class _DistRow extends StatelessWidget {
  final String label;
  final List<Session> sessions;
  final int maxPlaces;
  const _DistRow({required this.label, required this.sessions, required this.maxPlaces});

  static const _colors = [
    AppColors.place1, AppColors.place2, AppColors.place3, AppColors.place4,
  ];

  @override
  Widget build(BuildContext context) {
    final counts = [
      sessions.fold(0, (s, e) => s + e.count1),
      sessions.fold(0, (s, e) => s + e.count2),
      sessions.fold(0, (s, e) => s + e.count3),
      if (maxPlaces == 4) sessions.fold(0, (s, e) => s + e.count4),
    ];
    final total = counts.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.appInk.withAlpha(128))),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: List.generate(counts.length, (i) {
              final pct = total == 0 ? 0.0 : counts[i] / total;
              return Flexible(
                flex: (pct * 1000).round(),
                child: Container(
                  height: 18,
                  color: _colors[i],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(counts.length, (i) {
            final pct = total == 0 ? 0.0 : counts[i] / total * 100;
            return Expanded(
              child: Text(
                '${counts[i]}(${pct.toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── セクション6: 店舗別統計 ──────────────────────────────────────────────
class _ShopStats extends StatelessWidget {
  final List<Session> sessions;
  final bool withFees;
  const _ShopStats({required this.sessions, required this.withFees});

  @override
  Widget build(BuildContext context) {
    final shopNames = sessions.map((s) => s.shop).toSet().toList()..sort();

    return _AnalysisCard(
      title: '店舗別統計',
      child: Column(
        children: shopNames.map((name) {
          final ss = sessions.where((s) => s.shop == name).toList();
          final games = ss.fold(0, (sum, s) => sum + s.totalGames);
          final net   = ss.fold(0, (sum, s) => sum + getNet(s, withFees));
          final chip  = ss.fold(0, (sum, s) => sum + s.chipVal);
          final p1Rate= games == 0 ? 0.0
              : ss.fold(0, (s, e) => s + e.count1) / games * 100;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.notoSerif(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.appInk,
                    )),
                const SizedBox(height: 4),
                Row(
                  children: [
                    InfoBadge(text: '${ss.length}回',  color: AppColors.appInk),
                    InfoBadge(text: '$games局',       color: AppColors.appInk),
                    InfoBadge(text: '1着率${p1Rate.toStringAsFixed(0)}%', color: AppColors.appInk),
                    InfoBadge(
                      text:  signedCommaStr(net),
                      color: net >= 0 ? AppColors.appTeal : AppColors.appRed,
                    ),
                    if (chip != 0)
                      InfoBadge(
                        text:  'チップ${signedCommaStr(chip)}',
                        color: AppColors.appGold,
                      ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 共通ウィジェット ──────────────────────────────────────────────────────
class _AnalysisCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _AnalysisCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.appCream,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.appInk.withAlpha(18),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color:    AppColors.appInk.withAlpha(128),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.appInk.withAlpha(160))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
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
          Icon(Icons.bar_chart, size: 56, color: AppColors.appInk.withAlpha(60)),
          const SizedBox(height: 12),
          Text(
            isFiltered ? 'フィルターに一致する記録がありません' : 'データがありません',
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

// ── セッション詳細 BottomSheet ──────────────────────────────────────────────
class _SessionDetailSheet extends StatelessWidget {
  final Session session;
  final int     net;
  const _SessionDetailSheet({required this.session, required this.net});

  @override
  Widget build(BuildContext context) {
    final isFree = session.gameType == 'free';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy年M月d日 (E)', 'ja').format(session.date),
              style: TextStyle(fontSize: 13, color: AppColors.appInk.withAlpha(160)),
            ),
            const SizedBox(height: 4),
            Text(session.shop,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              '${session.players}人  ${session.format}  ${isFree ? "フリー" : "セット"}',
              style: TextStyle(fontSize: 12, color: AppColors.appInk.withAlpha(128)),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text('純収支',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.appInk.withAlpha(128))),
                  Text(
                    signedYen(net),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: net >= 0 ? AppColors.appTeal : AppColors.appRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RankPill(rank: 1, count: session.count1),
                _RankPill(rank: 2, count: session.count2),
                _RankPill(rank: 3, count: session.count3),
                if (session.players == 4)
                  _RankPill(rank: 4, count: session.count4),
              ],
            ),
            if (session.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(session.note,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.appInk.withAlpha(160))),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  final int rank;
  final int count;
  const _RankPill({required this.rank, required this.count});

  static const _colors = [
    AppColors.place1, AppColors.place2, AppColors.place3, AppColors.place4,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[rank - 1];
    return Column(
      children: [
        Text('$rank着',
            style: TextStyle(fontSize: 11, color: AppColors.appInk.withAlpha(128))),
        const SizedBox(height: 2),
        Text('$count回',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
