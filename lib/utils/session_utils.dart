import 'package:intl/intl.dart';

import '../models/session.dart';

final _numFormat = NumberFormat('#,###', 'ja_JP');

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

/// 符号付き文字列（コンマなし） 例: "+1500", "-320"
String signedStr(int v) => v >= 0 ? '+$v' : '$v';

/// 符号付きコンマ区切り（円なし） 例: "+15,000", "-3,200"
String signedCommaStr(int v) {
  if (v == 0) return '+0';
  final sign = v > 0 ? '+' : '-';
  return '$sign${_numFormat.format(v.abs())}';
}

/// 符号付きコンマ区切り（円あり） 例: "+15,000円", "-3,200円"
String signedYen(int v) {
  if (v == 0) return '±0円';
  final sign = v > 0 ? '+' : '-';
  return '$sign${_numFormat.format(v.abs())}円';
}

/// コンマ区切り円表示（符号なし） 例: "15,000円"
String formatYen(int v) => '${_numFormat.format(v)}円';

/// チャートY軸用 例: "+15k", "-3k", "+500"
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
