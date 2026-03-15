import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../utils/session_utils.dart';

enum PeriodFilter { all, thisMonth, lastMonth, last3Months }
enum PlayersFilter { all, three, four }
enum GameTypeFilter { all, free, set_ }
enum SortOrder { newest, oldest, highestNet, lowestNet }

class FilterState {
  final PeriodFilter period;
  final PlayersFilter players;
  final GameTypeFilter gameType;
  final String? shopId;  // shopName used as key
  final int? rate;
  final bool withFees;
  final SortOrder sortOrder;

  const FilterState({
    this.period = PeriodFilter.all,
    this.players = PlayersFilter.all,
    this.gameType = GameTypeFilter.all,
    this.shopId,
    this.rate,
    this.withFees = true,
    this.sortOrder = SortOrder.newest,
  });

  FilterState copyWith({
    PeriodFilter? period,
    PlayersFilter? players,
    GameTypeFilter? gameType,
    String? shopId,
    bool clearShopId = false,
    int? rate,
    bool clearRate = false,
    bool? withFees,
    SortOrder? sortOrder,
  }) =>
      FilterState(
        period: period ?? this.period,
        players: players ?? this.players,
        gameType: gameType ?? this.gameType,
        shopId: clearShopId ? null : (shopId ?? this.shopId),
        rate: clearRate ? null : (rate ?? this.rate),
        withFees: withFees ?? this.withFees,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((_) => FilterNotifier());

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(const FilterState());

  void update(FilterState Function(FilterState) fn) => state = fn(state);
  void reset() => state = const FilterState();
}

/// FilterState をセッションリストに適用して返す
List<Session> applyFilter(
    List<Session> all, FilterState f, bool withFees) {
  final now = DateTime.now();
  Iterable<Session> result = all;

  // 期間
  switch (f.period) {
    case PeriodFilter.thisMonth:
      result = result.where(
          (s) => s.date.year == now.year && s.date.month == now.month);
    case PeriodFilter.lastMonth:
      final last = DateTime(now.year, now.month - 1);
      result = result.where(
          (s) => s.date.year == last.year && s.date.month == last.month);
    case PeriodFilter.last3Months:
      final cutoff = DateTime(now.year, now.month - 2);
      result = result.where((s) => !s.date.isBefore(cutoff));
    case PeriodFilter.all:
      break;
  }

  // 人数
  if (f.players == PlayersFilter.three) result = result.where((s) => s.players == 3);
  if (f.players == PlayersFilter.four)  result = result.where((s) => s.players == 4);

  // 種別
  if (f.gameType == GameTypeFilter.free) result = result.where((s) => s.gameType == 'free');
  if (f.gameType == GameTypeFilter.set_) result = result.where((s) => s.gameType == 'set');

  // 店舗
  if (f.shopId != null) result = result.where((s) => s.shop == f.shopId);

  // レート
  if (f.rate != null) result = result.where((s) => s.rule == f.rate);

  // ソート
  final list = result.toList();
  switch (f.sortOrder) {
    case SortOrder.newest:
      list.sort((a, b) => b.date.compareTo(a.date));
    case SortOrder.oldest:
      list.sort((a, b) => a.date.compareTo(b.date));
    case SortOrder.highestNet:
      list.sort((a, b) => getNet(b, withFees).compareTo(getNet(a, withFees)));
    case SortOrder.lowestNet:
      list.sort((a, b) => getNet(a, withFees).compareTo(getNet(b, withFees)));
  }
  return list;
}
