// Giriş ekranı: raflarda kitap sırtları.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../theme/palettes.dart';
import '../widgets/shelf_widgets.dart';
import 'book_screen.dart';
import 'import_screen.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  static Future<void> addBook(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'epub', 'txt']);
    if (files.isEmpty || files.first.path == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImportScreen(path: files.first.path!)));
  }

  (String, String) _greeting() {
    final now = DateTime.now();
    const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final d = days[now.weekday - 1];
    final h = now.hour;
    if (h < 5) return ('$d gecesi', 'İyi geceler.');
    if (h < 12) return ('$d sabahı', 'Günaydın.');
    if (h < 17) return ('$d öğleden sonra', 'İyi günler.');
    if (h < 21) return ('$d akşamı', 'İyi akşamlar.');
    return ('$d gecesi', 'İyi geceler.');
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.palette;
    final (dayLabel, hello) = _greeting();
    final current = store.currentBook;
    final reading = store.books.where((b) => b.started && !b.finished).toList()
      ..sort((a, b) => (b.lastReadAt ?? 0).compareTo(a.lastReadAt ?? 0));
    final next = store.books.where((b) => !b.started && !b.finished).toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final done = store.books.where((b) => b.finished).toList();
    final goal = store.settings.dailyGoalMin;
    final todayMin = store.todaySeconds() ~/ 60;

    return SafeArea(
      bottom: false,
      child: Stack(children: [
        ListView(
          padding: EdgeInsets.fromLTRB(0, 0, 0, current != null ? 110 : 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 16, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(dayLabel.toUpperCase(), style: Fonts.label(p.muted)),
                    const SizedBox(height: 6),
                    Text(hello, style: Fonts.display(size: 32, color: p.text, height: 1.1)),
                    Text('Bir sayfa?', style: Fonts.display(size: 32, color: p.accent, height: 1.1, style: FontStyle.italic)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  StreakChip(days: store.streak()),
                  const SizedBox(height: 10),
                  IconButton(
                    tooltip: 'Kitap ekle',
                    onPressed: () => addBook(context),
                    style: IconButton.styleFrom(backgroundColor: p.text.withValues(alpha: 0.07), minimumSize: const Size(44, 44)),
                    icon: Icon(Icons.add, color: p.text),
                  ),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Column(children: [
                Row(children: [
                  Text('Bugünkü hedef', style: Fonts.ui(size: 13, color: p.muted)),
                  const Spacer(),
                  Text('${todayMin.clamp(0, 999)} / $goal dk', style: Fonts.ui(size: 13, color: p.text, weight: FontWeight.w500)),
                ]),
                const SizedBox(height: 8),
                ProgressLine(value: todayMin / goal, color: p.accent, track: p.text.withValues(alpha: 0.12), glow: p.dark),
              ]),
            ),
            if (store.books.isEmpty) _EmptyShelf(onAdd: () => addBook(context)),
            if (reading.isNotEmpty) _Shelf(title: 'Şu an okuduklarım', books: reading, highlightId: current?.id),
            if (next.isNotEmpty) _Shelf(title: 'Sırada', books: next, trailingAdd: () => addBook(context)),
            if (done.isNotEmpty) _Shelf(title: 'Bitirdiklerim · ${done.length}', books: done, dim: true),
          ],
        ),
        if (current != null)
          Positioned(left: 16, right: 16, bottom: 14, child: _ContinueCard(book: current)),
      ]),
    );
  }
}

class _Shelf extends StatelessWidget {
  final String title;
  final List<Book> books;
  final String? highlightId;
  final bool dim;
  final VoidCallback? trailingAdd;
  const _Shelf({required this.title, required this.books, this.highlightId, this.dim = false, this.trailingAdd});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Opacity(
      opacity: dim ? 0.7 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(title, style: Fonts.display(size: 15, color: p.muted)),
          ),
          SizedBox(
            height: 186,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                for (final b in books)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: BookSpine(
                        book: b,
                        highlighted: b.id == highlightId,
                        onTap: () => Navigator.of(context).push(_bookRoute(b)),
                        onLongPress: () => showBookMenu(context, b),
                      ),
                    ),
                  ),
                if (trailingAdd != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Semantics(
                        button: true,
                        label: 'Rafa kitap ekle',
                        child: GestureDetector(
                          onTap: trailingAdd,
                          child: Container(
                            width: 34,
                            height: 140,
                            decoration: BoxDecoration(
                              border: Border.all(color: p.muted.withValues(alpha: 0.45)),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                            child: Icon(Icons.add, color: p.muted, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Plank(),
        ]),
      ),
    );
  }
}

Route<void> _bookRoute(Book b) => PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: BookScreen(bookId: b.id)),
    );

Future<void> showBookMenu(BuildContext context, Book b) async {
  final store = AppScope.read(context);
  final p = store.palette;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(b.title, style: Fonts.display(size: 20, color: p.text), textAlign: TextAlign.center),
        ),
        ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Adını düzenle'), onTap: () => Navigator.pop(ctx, 'edit')),
        ListTile(
          leading: Icon(b.finished ? Icons.undo : Icons.check_circle_outline),
          title: Text(b.finished ? 'Okunmadı olarak işaretle' : 'Bitti olarak işaretle'),
          onTap: () => Navigator.pop(ctx, 'finish'),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Color(0xFFE06A5A)),
          title: const Text('Raftan kaldır', style: TextStyle(color: Color(0xFFE06A5A))),
          onTap: () => Navigator.pop(ctx, 'delete'),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'finish':
      b.finished = !b.finished;
      store.changed();
    case 'delete':
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Raftan kaldırılsın mı?'),
          content: Text('“${b.title}” ve okuma konumu silinecek. Okuma geçmişin kalır.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaldır')),
          ],
        ),
      );
      if (ok == true) await store.deleteBook(b);
    case 'edit':
      await editBookInfo(context, b);
  }
}

Future<void> editBookInfo(BuildContext context, Book b) async {
  final store = AppScope.read(context);
  final t = TextEditingController(text: b.title), a = TextEditingController(text: b.author);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kitap bilgisi'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: t, decoration: const InputDecoration(labelText: 'Kitap adı')),
        TextField(controller: a, decoration: const InputDecoration(labelText: 'Yazar')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
      ],
    ),
  );
  if (ok == true && t.text.trim().isNotEmpty) {
    b.title = t.text.trim();
    b.author = a.text.trim();
    store.changed();
  }
}

class _ContinueCard extends StatelessWidget {
  final Book book;
  const _ContinueCard({required this.book});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.palette;
    final look = SpineLook.of(book, p);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(_bookRoute(book)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.accent.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: p.dark ? 0.6 : 0.2), blurRadius: 40, offset: const Offset(0, 18))],
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 52,
              decoration: BoxDecoration(color: look.color, borderRadius: BorderRadius.circular(3)),
              alignment: Alignment.center,
              child: Container(width: 24, height: 36, decoration: BoxDecoration(border: Border.all(color: p.inkFor(look.color).withValues(alpha: 0.6)))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(size: 15, color: p.text)),
                const SizedBox(height: 3),
                Text('%${(book.progress * 100).toStringAsFixed(0)} okundu', style: Fonts.ui(size: 12, color: p.muted)),
              ]),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: book.id))),
              child: Text('Devam', style: Fonts.ui(weight: FontWeight.w600, color: p.onAccent)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyShelf({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 40, 18, 0),
      child: Column(children: [
        SizedBox(
          height: 170,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const SizedBox(width: 12),
            for (final w in [30.0, 22.0, 36.0])
              Container(
                width: w,
                height: 110 + w,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: p.muted.withValues(alpha: 0.3)),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            const Spacer(),
          ]),
        ),
        const Plank(),
        const SizedBox(height: 28),
        Text('Rafın seni bekliyor', style: Fonts.display(size: 22, color: p.text)),
        const SizedBox(height: 8),
        Text('Bir PDF, EPUB ya da TXT seç; onu okunur bir kitaba çevirip rafa koyalım.',
            textAlign: TextAlign.center, style: Fonts.ui(size: 14, color: p.muted, height: 1.5)),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            foregroundColor: p.onAccent,
            minimumSize: const Size(220, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text('İlk kitabını ekle', style: Fonts.ui(size: 15, weight: FontWeight.w600, color: p.onAccent)),
        ),
      ]),
    );
  }
}
