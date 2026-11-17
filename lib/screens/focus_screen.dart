// Odak sekmesi: süre seç, kaldığın kitapta zamanlı oturum başlat.
import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../theme/palettes.dart';
import '../widgets/shelf_widgets.dart';
import 'reader_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  int? _minutes;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.palette;
    final minutes = _minutes ?? store.settings.dailyGoalMin;
    final book = store.currentBook ?? (store.books.where((b) => !b.finished).isEmpty ? null : store.books.firstWhere((b) => !b.finished));
    final today = store.todaySeconds() ~/ 60;

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(22, 26, 22, 24), children: [
        Text('ODAK', style: Fonts.label(p.muted)),
        const SizedBox(height: 6),
        Text('Telefonu kitaba çevir.', style: Fonts.display(size: 30, color: p.text, height: 1.15)),
        const SizedBox(height: 10),
        Text('Süre seç, kitap açılsın; sayaç bitene kadar sadece sayfalar.',
            style: Fonts.ui(size: 14, color: p.muted, height: 1.5)),
        const SizedBox(height: 30),
        Center(
          child: SizedBox(
            width: 210,
            height: 210,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: (today / store.settings.dailyGoalMin).clamp(0.0, 1.0),
                  strokeWidth: 6,
                  color: p.accent,
                  backgroundColor: p.text.withValues(alpha: 0.08),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$minutes', style: Fonts.display(size: 64, color: p.text, height: 1)),
                Text('dakika', style: Fonts.ui(size: 14, color: p.muted)),
                const SizedBox(height: 6),
                Text('bugün $today / ${store.settings.dailyGoalMin} dk', style: Fonts.ui(size: 12, color: p.faint)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 26),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (final m in [10, 15, 20, 30, 45, 60])
            ChoiceChip(
              label: Text('$m dk'),
              selected: minutes == m,
              onSelected: (_) => setState(() => _minutes = m),
              selectedColor: p.accent,
              labelStyle: Fonts.ui(color: minutes == m ? p.onAccent : p.text, weight: FontWeight.w500),
              backgroundColor: p.text.withValues(alpha: 0.06),
              side: BorderSide(color: p.border),
              showCheckmark: false,
            ),
        ]),
        const SizedBox(height: 30),
        if (book != null) ...[
          Text('Kitap', style: Fonts.ui(size: 13, color: p.muted)),
          const SizedBox(height: 6),
          Text(book.title, style: Fonts.display(size: 20, color: p.text)),
          const SizedBox(height: 4),
          Text('%${(book.progress * 100).toStringAsFixed(0)} okundu', style: Fonts.ui(size: 13, color: p.muted)),
          const SizedBox(height: 20),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ReaderScreen(bookId: book.id, focusMinutes: minutes)),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('$minutes dakika oku', style: Fonts.ui(size: 16, weight: FontWeight.w600, color: p.onAccent)),
            ),
          ),
        ] else
          Text('Önce rafa bir kitap ekle.', textAlign: TextAlign.center, style: Fonts.ui(color: p.muted)),
        const SizedBox(height: 18),
        Center(child: StreakChip(days: store.streak())),
      ]),
    );
  }
}
