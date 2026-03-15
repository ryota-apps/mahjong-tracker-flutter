import 'package:uuid/uuid.dart';

class Shop {
  final String id;
  final String name;
  final int players;
  final String format;
  final int rule;
  final int chipUnit;
  final String chipNote;
  final int gameFee;
  final int topPrize;
  final DateTime createdAt;

  Shop({
    String? id,
    required this.name,
    this.players = 4,
    this.format = '東南戦',
    this.rule = 0,
    this.chipUnit = 0,
    this.chipNote = '',
    this.gameFee = 0,
    this.topPrize = 0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'players': players,
        'format': format,
        'rule': rule,
        'chipUnit': chipUnit,
        'chipNote': chipNote,
        'gameFee': gameFee,
        'topPrize': topPrize,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Shop.fromMap(Map<String, dynamic> m) => Shop(
        id: m['id'] as String,
        name: m['name'] as String,
        players: m['players'] as int,
        format: m['format'] as String,
        rule: m['rule'] as int,
        chipUnit: m['chipUnit'] as int,
        chipNote: m['chipNote'] as String? ?? '',
        gameFee: m['gameFee'] as int,
        topPrize: m['topPrize'] as int,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  Shop copyWith({
    String? id,
    String? name,
    int? players,
    String? format,
    int? rule,
    int? chipUnit,
    String? chipNote,
    int? gameFee,
    int? topPrize,
    DateTime? createdAt,
  }) =>
      Shop(
        id: id ?? this.id,
        name: name ?? this.name,
        players: players ?? this.players,
        format: format ?? this.format,
        rule: rule ?? this.rule,
        chipUnit: chipUnit ?? this.chipUnit,
        chipNote: chipNote ?? this.chipNote,
        gameFee: gameFee ?? this.gameFee,
        topPrize: topPrize ?? this.topPrize,
        createdAt: createdAt ?? this.createdAt,
      );
}
