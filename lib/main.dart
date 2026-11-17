import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';

import 'binder/importer.dart';
import 'data/library_store.dart';
import 'screens/book_screen.dart';
import 'screens/home_shell.dart';
import 'screens/reader_screen.dart';
import 'screens/intercept_screen.dart';
import 'services/home_widget.dart';
import 'services/intercept.dart';
import 'services/reminders.dart';
import 'theme/palettes.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false; // gömülü yazı tipleri kullanılır
  pdfrxFlutterInitialize();
  final store = LibraryStore();
  await store.load();
  runApp(PageraApp(store: store));
  // Arka plan işleri arayüzü bekletmesin.
  Reminders.init().catchError((_) {});
  Intercept.onIntercept = _showIntercept;
  Intercept.listen();
  Intercept.sync(store.settings);
  store.onChanged = HomeWidget.schedule;
  HomeWidget.push(store);
  try {
    final pending = await Intercept.consumePending();
    if (pending != null) _showIntercept(pending);
  } catch (_) {}
  await _demo(store);
}

/// Yalnız geliştirme: masaüstünde ekran görüntüsü almak için (--dart-define ile açılır).
Future<void> _demo(LibraryStore store) async {
  const pdf = String.fromEnvironment('PAGERA_DEMO_PDF');
  const screen = String.fromEnvironment('PAGERA_DEMO');
  if (pdf.isEmpty && screen.isEmpty) return;
  if (pdf.isNotEmpty && !File(pdf).existsSync()) return;
  if (pdf.isNotEmpty && store.books.isEmpty) {
    final c = await Importer.importFile(pdf, (_, _, _) {});
    final b = await store.addBook(Importer.guessTitle(pdf), '', c);
    store.savePosition(b, (c.totalChars * 0.38).round());
  }
  final nav = navigatorKey.currentState;
  if (nav == null || store.books.isEmpty) return;
  final id = store.books.first.id;
  if (screen == 'book') nav.push(MaterialPageRoute(builder: (_) => BookScreen(bookId: id)));
  if (screen == 'reader') nav.push(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: id)));
  if (screen == 'intercept') _showIntercept('com.instagram.android');
}

void _showIntercept(String pkg) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.push(MaterialPageRoute(builder: (_) => InterceptScreen(pkg: pkg)));
}

class PageraApp extends StatelessWidget {
  final LibraryStore store;
  const PageraApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final p = store.palette;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: MaterialApp(
              title: 'Pagera',
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              theme: buildTheme(p),
              home: const HomeShell(),
            ),
          );
        },
      ),
    );
  }
}
