import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'db/database_helper.dart';
import 'models/session.dart';
import 'screens/record/setup_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/analysis/analysis_screen.dart';
import 'screens/shops/shops_screen.dart';
import 'screens/data/data_screen.dart';

Future<void> _runDbSmokeTest() async {
  final db = DatabaseHelper.instance;

  // insert
  final s = Session(shop: 'テスト店', date: DateTime.now(), balance: 1000, net: 800);
  await db.insertSession(s);
  debugPrint('[DBTest] inserted: ${s.id}');

  // fetch
  final list = await db.getSessions();
  assert(list.isNotEmpty, 'getSessions returned empty');
  debugPrint('[DBTest] fetched ${list.length} session(s)');

  // delete
  await db.deleteSession(s.id);
  final after = await db.getSessions();
  assert(after.every((e) => e.id != s.id), 'deleteSession failed');
  debugPrint('[DBTest] delete OK — smoke test passed');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _runDbSmokeTest();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '麻雀トラッカー',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    SetupScreen(),
    HistoryScreen(),
    AnalysisScreen(),
    ShopsScreen(),
    DataScreen(),
  ];

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.edit), label: '記録する'),
    BottomNavigationBarItem(icon: Icon(Icons.list), label: '戦績一覧'),
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '分析'),
    BottomNavigationBarItem(icon: Icon(Icons.store), label: '店舗設定'),
    BottomNavigationBarItem(icon: Icon(Icons.upload_file), label: 'データ'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: _items,
      ),
    );
  }
}
