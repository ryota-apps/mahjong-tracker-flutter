import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_helper.dart';
import '../models/session.dart';

final sessionProvider =
    StateNotifierProvider<SessionNotifier, List<Session>>(
  (_) => SessionNotifier(),
);

class SessionNotifier extends StateNotifier<List<Session>> {
  SessionNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await DatabaseHelper.instance.getSessions();
  }

  Future<void> addSession(Session s) async {
    await DatabaseHelper.instance.insertSession(s);
    state = [s, ...state];
  }

  Future<void> updateSession(Session s) async {
    await DatabaseHelper.instance.updateSession(s);
    state = state.map((e) => e.id == s.id ? s : e).toList();
  }

  Future<void> deleteSession(String id) async {
    await DatabaseHelper.instance.deleteSession(id);
    state = state.where((e) => e.id != id).toList();
  }

  Future<void> deleteAll() async {
    await DatabaseHelper.instance.deleteAllSessions();
    state = [];
  }

  Future<void> refresh() async => _load();
}
