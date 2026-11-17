// "Reels yerine" ara ekranı: seçili uygulama açılınca gösterilir.
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../services/intercept.dart';
import '../theme/palettes.dart';
import '../widgets/shelf_widgets.dart';
import 'reader_screen.dart';

class InterceptScreen extends StatefulWidget {
  final String pkg;
  const InterceptScreen({super.key, required this.pkg});
  @override
  State<InterceptScreen> createState() => _InterceptScreenState();
}

class _InterceptScreenState extends State<InterceptScreen> {
  int _wait = 5;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wait <= 1) t.cancel();
      if (mounted) setState(() => _wait--);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _log(bool read) {
    final store = AppScope.read(context);
    store.interceptLog.add([DateTime.now().millisecondsSinceEpoch, read ? 1 : 0]);
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.palette;
    final book = store.currentBook ?? (store.books.where((b) => !b.finished).isEmpty ? null : store.books.firstWhere((b) => !b.finished));
    final weekAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final week = store.interceptLog.where((e) => e[0] >= weekAgo).toList();
    final chose = week.where((e) => e[1] == 1).length;
    final weekReadSecs = store.sessions.where((s) => s.start >= weekAgo).fold(0, (a, s) => a + s.seconds);
    final app = Intercept.nameOf(widget.pkg);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: p.dark ? const Color(0xFF0D0907) : p.bg.last,
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(children: [
                const Spacer(flex: 2),
                Icon(Icons.local_fire_department_outlined, size: 54, color: p.accent),
                const SizedBox(height: 16),
                Text("$app'I AÇMAK ÜZEREYDİN".toUpperCase(), textAlign: TextAlign.center, style: Fonts.label(p.muted)),
                const SizedBox(height: 12),
                Text('Kaydırmak yerine', textAlign: TextAlign.center, style: Fonts.display(size: 34, color: p.text, height: 1.15)),
                Text('5 sayfa?', textAlign: TextAlign.center, style: Fonts.display(size: 34, color: p.accent, height: 1.15, style: FontStyle.italic)),
                const SizedBox(height: 14),
                if (book != null)
                  Text('${book.title} seni %${(book.progress * 100).toStringAsFixed(0)}’de bekliyor.',
                      textAlign: TextAlign.center, style: Fonts.ui(size: 15, color: p.muted, height: 1.5)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.text.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(formatMinutes(weekReadSecs ~/ 60), style: Fonts.display(size: 22, color: p.accent)),
                        Text('bu hafta okudun', style: Fonts.ui(size: 12, color: p.muted)),
                      ]),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$chose / ${week.length}', style: Fonts.display(size: 22, color: p.text)),
                        Text('dürtüde kitabı seçtin', style: Fonts.ui(size: 12, color: p.muted)),
                      ]),
                    ),
                  ]),
                ),
                const Spacer(flex: 3),
                if (book != null)
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        foregroundColor: p.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () {
                        _log(true);
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: book.id, focusMinutes: 5)));
                      },
                      child: Text('5 sayfa oku', style: Fonts.ui(size: 16, weight: FontWeight.w600, color: p.onAccent)),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.text,
                      side: BorderSide(color: p.text.withValues(alpha: 0.18)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () {
                      _log(true);
                      Navigator.pop(context);
                    },
                    child: Text('Vazgeçtim, kapat', style: Fonts.ui(size: 15, color: p.text)),
                  ),
                ),
                TextButton(
                  onPressed: _wait > 0
                      ? null
                      : () async {
                          _log(false);
                          await Intercept.allowFor(widget.pkg, 10);
                          await Intercept.openApp(widget.pkg);
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: Text(_wait > 0 ? 'Yine de devam et · $_wait sn' : 'Yine de devam et (10 dk serbest)',
                      style: Fonts.ui(size: 14, color: p.faint)),
                ),
                const SizedBox(height: 10),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
