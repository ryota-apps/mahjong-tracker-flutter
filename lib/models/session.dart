import 'package:uuid/uuid.dart';

class Session {
  final String id;
  final String shop;
  final DateTime date;
  final int players;      // 3 or 4
  final String format;    // "東南戦" / "東風戦" / "その他"
  final int rule;         // レート（0=未設定）
  final String gameType;  // "free" or "set"
  final int count1;
  final int count2;
  final int count3;
  final int count4;
  final int balance;      // 現金収支
  final int chips;        // チップ枚数
  final int chipUnit;     // チップ単価
  final int chipVal;      // チップ収支（chips × chipUnit）
  final int venueFee;     // 場代
  final int net;          // 純収支
  final int gameFee;      // ゲーム代/局
  final int topPrize;     // トップ賞/回
  final String note;
  final DateTime createdAt;

  Session({
    String? id,
    required this.shop,
    required this.date,
    this.players = 4,
    this.format = '東南戦',
    this.rule = 0,
    this.gameType = 'free',
    this.count1 = 0,
    this.count2 = 0,
    this.count3 = 0,
    this.count4 = 0,
    this.balance = 0,
    this.chips = 0,
    this.chipUnit = 0,
    this.chipVal = 0,
    this.venueFee = 0,
    this.net = 0,
    this.gameFee = 0,
    this.topPrize = 0,
    this.note = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  int get totalGames => count1 + count2 + count3 + count4;

  Map<String, dynamic> toMap() => {
        'id': id,
        'shop': shop,
        'date': date.toIso8601String(),
        'players': players,
        'format': format,
        'rule': rule,
        'gameType': gameType,
        'count1': count1,
        'count2': count2,
        'count3': count3,
        'count4': count4,
        'balance': balance,
        'chips': chips,
        'chipUnit': chipUnit,
        'chipVal': chipVal,
        'venueFee': venueFee,
        'net': net,
        'gameFee': gameFee,
        'topPrize': topPrize,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Session.fromMap(Map<String, dynamic> m) => Session(
        id: m['id'] as String,
        shop: m['shop'] as String,
        date: DateTime.parse(m['date'] as String),
        players: m['players'] as int,
        format: m['format'] as String,
        rule: m['rule'] as int,
        gameType: m['gameType'] as String,
        count1: m['count1'] as int,
        count2: m['count2'] as int,
        count3: m['count3'] as int,
        count4: m['count4'] as int,
        balance: m['balance'] as int,
        chips: m['chips'] as int,
        chipUnit: m['chipUnit'] as int,
        chipVal: m['chipVal'] as int,
        venueFee: m['venueFee'] as int,
        net: m['net'] as int,
        gameFee: m['gameFee'] as int,
        topPrize: m['topPrize'] as int,
        note: m['note'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  Session copyWith({
    String? id,
    String? shop,
    DateTime? date,
    int? players,
    String? format,
    int? rule,
    String? gameType,
    int? count1,
    int? count2,
    int? count3,
    int? count4,
    int? balance,
    int? chips,
    int? chipUnit,
    int? chipVal,
    int? venueFee,
    int? net,
    int? gameFee,
    int? topPrize,
    String? note,
    DateTime? createdAt,
  }) =>
      Session(
        id: id ?? this.id,
        shop: shop ?? this.shop,
        date: date ?? this.date,
        players: players ?? this.players,
        format: format ?? this.format,
        rule: rule ?? this.rule,
        gameType: gameType ?? this.gameType,
        count1: count1 ?? this.count1,
        count2: count2 ?? this.count2,
        count3: count3 ?? this.count3,
        count4: count4 ?? this.count4,
        balance: balance ?? this.balance,
        chips: chips ?? this.chips,
        chipUnit: chipUnit ?? this.chipUnit,
        chipVal: chipVal ?? this.chipVal,
        venueFee: venueFee ?? this.venueFee,
        net: net ?? this.net,
        gameFee: gameFee ?? this.gameFee,
        topPrize: topPrize ?? this.topPrize,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );
}
