import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'screens/record/setup_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/analysis/analysis_screen.dart';
import 'screens/shops/shops_screen.dart';
import 'screens/data/data_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja_JP', null);
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
    BottomNavigationBarItem(icon: Icon(Icons.edit), label: '記録'),
    BottomNavigationBarItem(icon: Icon(Icons.list), label: '一覧'),
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '分析'),
    BottomNavigationBarItem(icon: Icon(Icons.store), label: '店舗'),
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
