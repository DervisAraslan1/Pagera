// Alt menülü ana iskelet: Kütüphane · Odak · İlerleme · Ayarlar.
import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../theme/palettes.dart';
import '../widgets/shelf_widgets.dart';
import 'focus_screen.dart';
import 'library_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    const items = [
      (Icons.auto_stories_outlined, 'Kütüphane'),
      (Icons.timer_outlined, 'Odak'),
      (Icons.insights_outlined, 'İlerleme'),
      (Icons.tune_outlined, 'Ayarlar'),
    ];
    return Scaffold(
      body: AppBackground(
        child: IndexedStack(index: _tab, children: const [
          LibraryScreen(),
          FocusScreen(),
          ProgressScreen(),
          SettingsScreen(),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: p.nav, border: Border(top: BorderSide(color: p.border))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkResponse(
                    onTap: () => setState(() => _tab = i),
                    child: Semantics(
                      selected: _tab == i,
                      button: true,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(items[i].$1, size: 23, color: _tab == i ? p.accent : p.faint),
                        const SizedBox(height: 4),
                        Text(items[i].$2,
                            style: Fonts.ui(size: 11, weight: FontWeight.w500, color: _tab == i ? p.accent : p.faint)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
