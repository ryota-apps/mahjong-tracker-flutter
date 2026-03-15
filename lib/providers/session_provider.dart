import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_helper.dart';
import '../models/session.dart';

class SessionState {
  final List<Session> sessions;
  final bool isLoading;

  const SessionState({required this.sessions, this.isLoading = true});

  SessionState copyWith({List<Session>? sessions, bool? isLoading}) =>
      SessionState(
        sessions:  sessions  ?? this.sessions,
        isLoading: isLoading ?? this.isLoading,
      );
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>(
  (_) => SessionNotifier(),
);

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState(sessions: [])) {
    _load();
  }

  Future<void> _load() async {
    final sessions = await DatabaseHelper.instance.getSessions();
    state = SessionState(sessions: sessions, isLoading: false);
  }

  Future<void> addSession(Session s) async {
    await DatabaseHelper.instance.insertSession(s);
    state = state.copyWith(sessions: [s, ...state.sessions]);
  }

  Future<void> updateSession(Session s) async {
    await DatabaseHelper.instance.updateSession(s);
    state = state.copyWith(
        sessions: state.sessions.map((e) => e.id == s.id ? s : e).toList());
  }

  Future<void> deleteSession(String id) async {
    await DatabaseHelper.instance.deleteSession(id);
    state = state.copyWith(
        sessions: state.sessions.where((e) => e.id != id).toList());
  }

  Future<void> deleteAll() async {
    await DatabaseHelper.instance.deleteAllSessions();
    state = state.copyWith(sessions: []);
  }

  Future<void> refresh() async => _load();
}
