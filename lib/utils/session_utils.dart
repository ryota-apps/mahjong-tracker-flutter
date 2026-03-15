import '../models/session.dart';

/// ゲーム代差し引きを考慮した純収支を返す。
int getNet(Session session, bool withFees) {
  if (withFees) return session.net;
  if (session.gameType == 'set') return session.net + session.venueFee;
  if (session.gameFee > 0 || session.topPrize > 0) {
    return session.net +
        session.totalGames * session.gameFee +
        session.count1 * session.topPrize;
  }
  return session.net;
}

String signedStr(int v) => v >= 0 ? '+$v' : '$v';

String signedKStr(int v) {
  if (v.abs() >= 1000) {
    final k = (v / 1000).toStringAsFixed(0);
    return v >= 0 ? '+${k}k' : '${k}k';
  }
  return signedStr(v);
}

/// 今日の全セッションの net 合計
int todayNetTotal(List<Session> sessions) {
  final today = DateTime.now();
  return sessions
      .where((s) =>
          s.date.year == today.year &&
          s.date.month == today.month &&
          s.date.day == today.day)
      .fold(0, (sum, s) => sum + s.net);
}
