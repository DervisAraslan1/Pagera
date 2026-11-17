// Raftan çekilmiş kitap: kapak, ilerleme, okumaya başla.
import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../theme/palettes.dart';
import '../widgets/shelf_widgets.dart';
import 'library_screen.dart';
import 'notes_screen.dart';
import 'reader_screen.dart';

class BookScreen extends StatelessWidget {
  final String bookId;
  const BookScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.palette;
    final book = store.byId(bookId);
    if (book == null) return const Scaffold();
    final remainingMin = ((book.totalChars - book.position) / store.charsPerMinute()).round();
    final sessions = store.sessionsFor(book);
    final readMin = store.secondsFor(book) ~/ 60;

    void open({int? focusMinutes}) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReaderScreen(bookId: book.id, focusMinutes: focusMinutes)),
        );

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                IconButton(
                  tooltip: 'Rafa geri koy',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: p.text.withValues(alpha: 0.08), minimumSize: const Size(44, 44)),
                  icon: Icon(Icons.chevron_left, color: p.text),
                ),
                const Spacer(),
                Text('RAFTAN ÇEKİLDİ', style: Fonts.label(p.muted)),
                const Spacer(),
                IconButton(
                  tooltip: 'Diğer',
                  onPressed: () => showBookMenu(context, book),
                  style: IconButton.styleFrom(backgroundColor: p.text.withValues(alpha: 0.08), minimumSize: const Size(44, 44)),
                  icon: Icon(Icons.more_horiz, color: p.text),
                ),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 26), children: [
                const SizedBox(height: 22),
                Center(
                  child: Hero(
                    tag: 'book-${book.id}',
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0011)
                        ..rotateY(-0.2),
                      child: BookCover(book: book, width: 190),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(book.title, textAlign: TextAlign.center, style: Fonts.display(size: 28, color: p.text, height: 1.15)),
                const SizedBox(height: 6),
                Text(
                  [if (book.author.isNotEmpty) book.author, formatMinutes((book.totalChars / store.charsPerMinute()).round())].join(' · '),
                  textAlign: TextAlign.center,
                  style: Fonts.ui(size: 14, color: p.muted),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  _Stat(value: '%${(book.progress * 100).toStringAsFixed(0)}', label: 'bitti', accent: true),
                  const SizedBox(width: 10),
                  _Stat(value: book.finished ? '—' : formatMinutes(remainingMin), label: 'kaldı'),
                  const SizedBox(width: 10),
                  _Stat(value: '$sessions', label: readMin > 0 ? 'oturum · ${formatMinutes(readMin)}' : 'oturum'),
                ]),
                const SizedBox(height: 22),
                ProgressLine(value: book.progress, color: p.accent, track: p.text.withValues(alpha: 0.12)),
                const SizedBox(height: 18),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotesScreen(bookId: book.id))),
                    icon: Icon(Icons.format_quote, color: p.accent),
                    label: Text('Notlarım · ${store.highlightsFor(book.id).length}', style: Fonts.ui(size: 15, color: p.text)),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accent,
                      foregroundColor: p.onAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => open(),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(book.started ? 'Kaldığın yerden aç' : 'Okumaya başla',
                        style: Fonts.ui(size: 16, weight: FontWeight.w600, color: p.onAccent)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.text,
                      side: BorderSide(color: p.text.withValues(alpha: 0.18)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => open(focusMinutes: store.settings.dailyGoalMin),
                    icon: const Icon(Icons.timer_outlined, size: 19),
                    label: Text('${store.settings.dailyGoalMin} dakikalık odak oturumu', style: Fonts.ui(size: 15, color: p.text)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final bool accent;
  const _Stat({required this.value, required this.label, this.accent = false});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: p.text.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          FittedBox(child: Text(value, style: Fonts.display(size: 21, color: accent ? p.accent : p.text))),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: Fonts.ui(size: 12, color: p.muted)),
        ]),
      ),
    );
  }
}
