import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/session.dart';
import '../models/shop.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'mahjong_tracker.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        shop TEXT NOT NULL,
        date TEXT NOT NULL,
        players INTEGER NOT NULL,
        format TEXT NOT NULL,
        rule INTEGER NOT NULL,
        gameType TEXT NOT NULL,
        count1 INTEGER NOT NULL,
        count2 INTEGER NOT NULL,
        count3 INTEGER NOT NULL,
        count4 INTEGER NOT NULL,
        balance INTEGER NOT NULL,
        chips INTEGER NOT NULL,
        chipUnit INTEGER NOT NULL,
        chipVal INTEGER NOT NULL,
        venueFee INTEGER NOT NULL,
        net INTEGER NOT NULL,
        gameFee INTEGER NOT NULL,
        topPrize INTEGER NOT NULL,
        note TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE shops (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        players INTEGER NOT NULL,
        format TEXT NOT NULL,
        rule INTEGER NOT NULL,
        chipUnit INTEGER NOT NULL,
        chipNote TEXT NOT NULL,
        gameFee INTEGER NOT NULL,
        topPrize INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  // ── Session ──────────────────────────────────────────────

  Future<List<Session>> getSessions() async {
    final db = await database;
    final rows = await db.query('sessions', orderBy: 'date DESC');
    return rows.map(Session.fromMap).toList();
  }

  Future<void> insertSession(Session s) async {
    final db = await database;
    await db.insert('sessions', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(Session s) async {
    final db = await database;
    await db.update('sessions', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllSessions() async {
    final db = await database;
    await db.delete('sessions');
  }

  // ── Shop ─────────────────────────────────────────────────

  Future<List<Shop>> getShops() async {
    final db = await database;
    final rows = await db.query('shops', orderBy: 'createdAt ASC');
    return rows.map(Shop.fromMap).toList();
  }

  Future<void> insertShop(Shop s) async {
    final db = await database;
    await db.insert('shops', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateShop(Shop s) async {
    final db = await database;
    await db.update('shops', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> deleteShop(String id) async {
    final db = await database;
    await db.delete('shops', where: 'id = ?', whereArgs: [id]);
  }
}
