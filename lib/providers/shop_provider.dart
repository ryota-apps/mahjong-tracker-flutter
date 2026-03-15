import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_helper.dart';
import '../models/shop.dart';

final shopProvider =
    StateNotifierProvider<ShopNotifier, List<Shop>>(
  (_) => ShopNotifier(),
);

class ShopNotifier extends StateNotifier<List<Shop>> {
  ShopNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await DatabaseHelper.instance.getShops();
  }

  Future<void> addShop(Shop s) async {
    await DatabaseHelper.instance.insertShop(s);
    state = [...state, s];
  }

  Future<void> updateShop(Shop s) async {
    await DatabaseHelper.instance.updateShop(s);
    state = state.map((e) => e.id == s.id ? s : e).toList();
  }

  Future<void> deleteShop(String id) async {
    await DatabaseHelper.instance.deleteShop(id);
    state = state.where((e) => e.id != id).toList();
  }

  Future<void> refresh() async => _load();
}
