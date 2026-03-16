import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../models/shop.dart';
import '../../providers/shop_provider.dart';
import '../../utils/session_utils.dart';
import '../../widgets/info_badge.dart';

const _formatOptions = ['東南戦', '東風戦', 'その他'];
const _rateOptions   = [0, 1, 2, 3, 5, 10, 20, 30, 50];

class ShopsScreen extends ConsumerWidget {
  const ShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(shopProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(title: const Text('店舗設定')),
        body: shops.isEmpty
            ? _EmptyState(onAdd: () => _openForm(context))
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: shops.length,
                      itemBuilder: (_, i) =>
                          _ShopTile(shop: shops[i]),
                    ),
                  ),
                  _AddButton(onTap: () => _openForm(context)),
                ],
              ),
      ),
    );
  }

  void _openForm(BuildContext context, [Shop? shop]) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      builder:            (_) => _ShopFormSheet(existing: shop),
    );
  }
}

// ── 追加ボタン（リスト下部） ──────────────────────────────────────────────
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.appInk,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.add, color: AppColors.appPaper),
          label: const Text('新しい店舗を追加',
              style: TextStyle(color: AppColors.appPaper, fontSize: 15)),
        ),
      ),
    );
  }
}

// ── 店舗タイル ──────────────────────────────────────────────────────────────
class _ShopTile extends ConsumerWidget {
  final Shop shop;
  const _ShopTile({required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: Key(shop.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.38,
          children: [
            SlidableAction(
              onPressed: (_) => _openForm(context),
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
        child: _ShopCard(
          shop:     shop,
          onEdit:   () => _openForm(context),
          onDelete: () => _delete(context, ref),
        ),
      ),
    );
  }

  void _openForm(BuildContext context) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      builder:            (_) => _ShopFormSheet(existing: shop),
    );
  }

  void _delete(BuildContext context, WidgetRef ref) {
    final deleted = shop;
    ref.read(shopProvider.notifier).deleteShop(shop.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('「${shop.name}」を削除しました'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () => ref.read(shopProvider.notifier).addShop(deleted),
        ),
      ));
  }
}

// ── 店舗カード ──────────────────────────────────────────────────────────────
class _ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ShopCard({required this.shop, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Expanded(
                child: Text(shop.name,
                    style: GoogleFonts.notoSerif(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppColors.appInk,
                    )),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: AppColors.appTeal,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: AppColors.appRed,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              InfoBadge(text: '${shop.players}人',   color: AppColors.appInk),
              InfoBadge(text: shop.format,            color: AppColors.appInk),
              if (shop.rule > 0)
                InfoBadge(text: '${shop.rule}pt',    color: AppColors.appInk),
              if (shop.chipUnit > 0)
                InfoBadge(text: 'チップ${formatYen(shop.chipUnit)}', color: AppColors.appGold),
              if (shop.gameFee > 0)
                InfoBadge(text: 'ゲーム代${formatYen(shop.gameFee)}',  color: AppColors.appTeal),
              if (shop.topPrize > 0)
                InfoBadge(text: 'トップ賞${formatYen(shop.topPrize)}', color: AppColors.appTeal),
              if (shop.chipNote.isNotEmpty)
                InfoBadge(text: shop.chipNote, color: AppColors.appInk),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 店舗フォームシート ────────────────────────────────────────────────────
class _ShopFormSheet extends ConsumerStatefulWidget {
  final Shop? existing;
  const _ShopFormSheet({this.existing});

  @override
  ConsumerState<_ShopFormSheet> createState() => _ShopFormSheetState();
}

class _ShopFormSheetState extends ConsumerState<_ShopFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _chipUnitCtrl;
  late final TextEditingController _chipNoteCtrl;
  late final TextEditingController _gameFeeCtrl;
  late final TextEditingController _topPrizeCtrl;

  late int    _players;
  late String _format;
  late int    _rule;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameCtrl     = TextEditingController(text: s?.name      ?? '');
    _chipUnitCtrl = TextEditingController(text: '${s?.chipUnit ?? 0}');
    _chipNoteCtrl = TextEditingController(text: s?.chipNote   ?? '');
    _gameFeeCtrl  = TextEditingController(text: '${s?.gameFee  ?? 0}');
    _topPrizeCtrl = TextEditingController(text: '${s?.topPrize ?? 0}');
    _players = s?.players ?? 4;
    _format  = s?.format  ?? '東南戦';
    _rule    = s?.rule     ?? 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _chipUnitCtrl.dispose(); _chipNoteCtrl.dispose();
    _gameFeeCtrl.dispose(); _topPrizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title:   const Text('エラー'),
          content: const Text('店舗名を入力してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final shop = Shop(
      id:        widget.existing?.id,
      name:      name,
      players:   _players,
      format:    _format,
      rule:      _rule,
      chipUnit:  int.tryParse(_chipUnitCtrl.text) ?? 0,
      chipNote:  _chipNoteCtrl.text.trim(),
      gameFee:   int.tryParse(_gameFeeCtrl.text)  ?? 0,
      topPrize:  int.tryParse(_topPrizeCtrl.text) ?? 0,
      createdAt: widget.existing?.createdAt,
    );

    if (widget.existing == null) {
      await ref.read(shopProvider.notifier).addShop(shop);
    } else {
      await ref.read(shopProvider.notifier).updateShop(shop);
    }
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.appInk.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.existing == null ? '店舗を追加' : '店舗を編集',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // 店舗名
              _FormField(
                label: '店舗名（必須）',
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText:  '例: ○○雀荘',
                    border:    InputBorder.none,
                    isDense:   true,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 人数
              _FormField(
                label: 'デフォルト人数',
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 4, label: Text('4人')),
                    ButtonSegment(value: 3, label: Text('3人')),
                  ],
                  selected: {_players},
                  onSelectionChanged: (s) => setState(() => _players = s.first),
                ),
              ),
              const SizedBox(height: 12),

              // 戦型
              _FormField(
                label: 'デフォルト戦型',
                child: DropdownButton<String>(
                  value:       _format,
                  isExpanded:  true,
                  underline:   const SizedBox.shrink(),
                  items: _formatOptions.map((f) => DropdownMenuItem(
                    value: f, child: Text(f))).toList(),
                  onChanged: (v) => setState(() => _format = v ?? '東南戦'),
                ),
              ),
              const SizedBox(height: 12),

              // レート
              _FormField(
                label: 'レート',
                child: DropdownButton<int>(
                  value:      _rule,
                  isExpanded: true,
                  underline:  const SizedBox.shrink(),
                  items: _rateOptions.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r == 0 ? '未設定' : '$r点'))).toList(),
                  onChanged: (v) => setState(() => _rule = v ?? 0),
                ),
              ),
              const SizedBox(height: 12),

              // チップ単価
              _FormField(
                label: 'チップ単価（任意）',
                child: _NumInput(ctrl: _chipUnitCtrl),
              ),
              const SizedBox(height: 12),

              // チップメモ
              _FormField(
                label: 'チップ種別メモ（任意）',
                child: TextField(
                  controller: _chipNoteCtrl,
                  decoration: const InputDecoration(
                    hintText: '例: 赤チップ',
                    border:   InputBorder.none,
                    isDense:  true,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ゲーム代
              _FormField(
                label: 'ゲーム代（任意）',
                child: _NumInput(ctrl: _gameFeeCtrl),
              ),
              const SizedBox(height: 12),

              // トップ賞
              _FormField(
                label: 'トップ賞（任意）',
                child: _NumInput(ctrl: _topPrizeCtrl),
              ),
              const SizedBox(height: 20),

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
                          backgroundColor: AppColors.appInk),
                      child: const Text('保存',
                          style: TextStyle(color: AppColors.appPaper)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 空状態 ──────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store, size: 56, color: AppColors.appInk.withAlpha(60)),
          const SizedBox(height: 12),
          Text('店舗が登録されていません',
              style: TextStyle(color: AppColors.appInk.withAlpha(100), fontSize: 16)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(backgroundColor: AppColors.appInk),
            icon: const Icon(Icons.add),
            label: const Text('店舗を追加する'),
          ),
        ],
      ),
    );
  }
}

// ── 小部品 ─────────────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.appCream,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: AppColors.appInk.withAlpha(12),
              blurRadius: 3,
              offset: const Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize:    11,
                  color:       AppColors.appInk.withAlpha(128),
                  letterSpacing: 0.4)),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}

class _NumInput extends StatelessWidget {
  final TextEditingController ctrl;
  const _NumInput({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:  ctrl,
      keyboardType: TextInputType.number,
      decoration:  const InputDecoration(
        border:  InputBorder.none,
        isDense: true,
      ),
    );
  }
}

