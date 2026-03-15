import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../db/database_helper.dart';
import '../../models/session.dart';
import '../../models/shop.dart';
import '../../providers/session_provider.dart';
import '../../providers/shop_provider.dart';
import '../../widgets/toast_widget.dart';

const _kICloudEnabled    = 'icloud_enabled';
const _kICloudLastSync   = 'icloud_last_sync';
const _iCloudContainerId = 'iCloud.com.ryota.mahjongtracker';

class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _icloudEnabled = false;
  String? _lastSyncStr;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndAutoSync();
  }

  Future<void> _loadPrefsAndAutoSync() async {
    final p = await SharedPreferences.getInstance();
    final enabled = p.getBool(_kICloudEnabled) ?? false;
    setState(() {
      _icloudEnabled = enabled;
      _lastSyncStr   = p.getString(_kICloudLastSync);
    });
    // 起動時：ONなら自動同期
    if (enabled) {
      await _icloudBackup();
    }
  }

  Future<void> _toggleICloud(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kICloudEnabled, enabled);
    setState(() => _icloudEnabled = enabled);
    // トグルONにした瞬間に自動同期
    if (enabled) {
      await _icloudBackup();
    }
  }

  // ── JSON エクスポート ──────────────────────────────────────────────────────
  Future<void> _exportJson() async {
    final sessions = ref.read(sessionProvider);
    final shops    = ref.read(shopProvider);
    final json = jsonEncode({
      'sessions': sessions.map((s) => s.toMap()).toList(),
      'shops':    shops.map((s)    => s.toMap()).toList(),
    });

    final dir  = await getTemporaryDirectory();
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${dir.path}/麻雀成績_バックアップ_$date.json');
    await file.writeAsString(json, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: '麻雀成績バックアップ',
    );
  }

  // ── CSV エクスポート ──────────────────────────────────────────────────────
  Future<void> _exportCsv() async {
    final sessions = ref.read(sessionProvider);

    const header = '\uFEFF'  // BOM
        '日付,店舗名,人数,戦型,種別,レート,'
        '1着,2着,3着,4着,総ゲーム数,'
        '現金収支,チップ枚数,チップ収支,場代,純収支,メモ\n';

    final rows = sessions.map((s) {
      final cols = [
        DateFormat('yyyy/MM/dd').format(s.date),
        s.shop,
        s.players,
        s.format,
        s.gameType == 'free' ? 'フリー' : 'セット',
        s.rule,
        s.count1, s.count2, s.count3, s.count4,
        s.totalGames,
        s.balance, s.chips, s.chipVal, s.venueFee, s.net,
        s.note.replaceAll(',', '、'),
      ];
      return cols.join(',');
    }).join('\n');

    final csv  = header + rows;
    final dir  = await getTemporaryDirectory();
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${dir.path}/麻雀成績_$date.csv');
    await file.writeAsString(csv, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: '麻雀成績CSV',
    );
  }

  // ── JSON インポート ────────────────────────────────────────────────────────
  Future<void> _importJson() async {
    final result = await FilePicker.platform.pickFiles(
      type:             FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    try {
      final raw  = await File(result.files.single.path!).readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final existingSessions = ref.read(sessionProvider);
      final existingShops    = ref.read(shopProvider);

      final existingSessionIds = existingSessions.map((s) => s.id).toSet();
      final existingShopIds    = existingShops.map((s)    => s.id).toSet();

      int importedSessions = 0;
      int importedShops    = 0;

      if (data['sessions'] != null) {
        for (final row in data['sessions'] as List) {
          final s = Session.fromMap(row as Map<String, dynamic>);
          if (!existingSessionIds.contains(s.id)) {
            await DatabaseHelper.instance.insertSession(s);
            importedSessions++;
          }
        }
      }
      if (data['shops'] != null) {
        for (final row in data['shops'] as List) {
          final s = Shop.fromMap(row as Map<String, dynamic>);
          if (!existingShopIds.contains(s.id)) {
            await DatabaseHelper.instance.insertShop(s);
            importedShops++;
          }
        }
      }

      await ref.read(sessionProvider.notifier).refresh();
      await ref.read(shopProvider.notifier).refresh();

      if (mounted) {
        showToast(
          context,
          '$importedSessions件のセッション、$importedShops件の店舗をインポートしました',
        );
      }
    } on FormatException catch (e) {
      debugPrint('importJson FormatException: $e');
      if (mounted) showToast(context, 'ファイルの形式が不正です。正しいバックアップファイルを選択してください。');
    } catch (e) {
      debugPrint('importJson error: $e');
      if (mounted) showToast(context, 'インポートに失敗しました。ファイルを確認してください。');
    }
  }

  // ── iCloud バックアップ ────────────────────────────────────────────────────
  Future<void> _icloudBackup() async {
    setState(() => _syncing = true);
    try {
      final sessions = ref.read(sessionProvider);
      final shops    = ref.read(shopProvider);
      final json = jsonEncode({
        'sessions': sessions.map((s) => s.toMap()).toList(),
        'shops':    shops.map((s)    => s.toMap()).toList(),
      });

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/mahjong_backup.json');
      await file.writeAsString(json, encoding: utf8);

      await ICloudStorage.upload(
        containerId: _iCloudContainerId,
        filePath:    file.path,
        destinationRelativePath: '麻雀成績集計/mahjong_backup.json',
        onProgress: (_) {},
      );

      final now = DateTime.now();
      final p   = await SharedPreferences.getInstance();
      await p.setString(
          _kICloudLastSync, DateFormat('yyyy/MM/dd HH:mm').format(now));
      setState(() => _lastSyncStr =
          DateFormat('yyyy/MM/dd HH:mm').format(now));

      if (mounted) showToast(context, 'iCloudにバックアップしました');
    } catch (e) {
      if (mounted) showToast(context, 'iCloud同期に失敗しました: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  // ── 全削除 ────────────────────────────────────────────────────────────────
  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('すべてのデータを削除'),
        content: const Text('セッションデータをすべて削除します。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する',
                style: TextStyle(color: AppColors.appRed)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(sessionProvider.notifier).deleteAll();
      if (mounted) showToast(context, 'すべてのデータを削除しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('データ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── iCloud同期 ──────────────────────────────────────────────────
          _Section(
            title: 'iCloud同期',
            children: [
              _TileRow(
                label: 'iCloudバックアップ',
                trailing: Switch(
                  value:    _icloudEnabled,
                  onChanged: _toggleICloud,
                  activeThumbColor: AppColors.appTeal,
                ),
              ),
              _TileRow(
                label: '最終同期',
                trailing: _syncing
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        _lastSyncStr ?? '未同期',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.appInk.withAlpha(160))),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4, left: 2),
                child: Text(
                  'ONにした瞬間・アプリ起動時に自動でバックアップします',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.appInk.withAlpha(120)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── エクスポート ─────────────────────────────────────────────────
          _Section(
            title: 'エクスポート',
            children: [
              _ActionTile(
                icon:    Icons.download,
                label:   'JSONエクスポート',
                subtitle: 'セッション・店舗データを全件書き出し',
                onTap:   _exportJson,
              ),
              _ActionTile(
                icon:    Icons.table_chart,
                label:   'CSVエクスポート',
                subtitle: 'BOM付きUTF-8、Excelで開けます',
                onTap:   _exportCsv,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── インポート ────────────────────────────────────────────────────
          _Section(
            title: 'インポート（復元）',
            children: [
              _ActionTile(
                icon:    Icons.upload_file,
                label:   'JSONから復元',
                subtitle: '重複IDはスキップされます',
                onTap:   _importJson,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── データ管理 ────────────────────────────────────────────────────
          _Section(
            title: 'データ管理',
            children: [
              _TileRow(
                label: '現在のセッション数',
                trailing: Text('${sessions.length}件',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _deleteAll,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.appRed),
                    foregroundColor: AppColors.appRed,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('すべてのデータを削除'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── ウィジェット ──────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String        title;
  final List<Widget>  children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.appCream,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.appInk.withAlpha(15),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize:    12,
                  color:       AppColors.appInk.withAlpha(128),
                  fontWeight:  FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _TileRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _TileRow({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.appTeal, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color:    AppColors.appInk.withAlpha(128))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppColors.appInk.withAlpha(80), size: 20),
          ],
        ),
      ),
    );
  }
}
