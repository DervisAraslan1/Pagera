// Kitabın altı çizili cümleleri ve notları.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_store.dart';
import '../theme/palettes.dart';
import '../widgets/shelf_widgets.dart';
import 'reader_screen.dart';

class NotesScreen extends StatelessWidget {
  final String bookId;
  const NotesScreen({super.key, required this.bookId});

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const m = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.palette;
    final book = store.byId(bookId);
    if (book == null) return const Scaffold();
    final list = store.highlightsFor(bookId);

    Future<void> open(Highlight h) async {
      final c = await store.content(book);
      if (!context.mounted || h.block >= c.offsets.length) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: bookId, startAt: c.offsets[h.block] + h.start)));
    }

    Future<void> menu(Highlight h) async {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.menu_book_outlined), title: const Text('Kitapta aç'), onTap: () => Navigator.pop(ctx, 'open')),
            ListTile(leading: const Icon(Icons.copy_outlined), title: const Text('Kopyala'), onTap: () => Navigator.pop(ctx, 'copy')),
            ListTile(leading: const Icon(Icons.edit_note), title: const Text('Notu düzenle'), onTap: () => Navigator.pop(ctx, 'note')),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFE06A5A)),
              title: const Text('Sil', style: TextStyle(color: Color(0xFFE06A5A))),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ]),
        ),
      );
      if (!context.mounted) return;
      switch (choice) {
        case 'open':
          await open(h);
        case 'copy':
          await Clipboard.setData(ClipboardData(text: h.note.isEmpty ? h.text : '${h.text}\n\n— ${h.note}'));
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kopyalandı')));
        case 'note':
          final c = TextEditingController(text: h.note);
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Not'),
              content: TextField(controller: c, autofocus: true, maxLines: 4),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
              ],
            ),
          );
          if (ok == true) {
            h.note = c.text.trim();
            store.changed();
          }
        case 'delete':
          store.removeHighlight(h);
      }
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(tooltip: 'Geri', onPressed: () => Navigator.pop(context), icon: Icon(Icons.chevron_left, color: p.text)),
                Expanded(child: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.ui(size: 14, color: p.muted))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
              child: Text('Notlarım', style: Fonts.display(size: 30, color: p.text)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Text('${list.length} altı çizili yer', style: Fonts.ui(size: 13, color: p.muted)),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Okurken bir paragrafa uzun bas; beğendiğin cümlenin altını çiz, burada toplansın.',
                            textAlign: TextAlign.center, style: Fonts.ui(size: 14, color: p.muted, height: 1.5)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => Divider(color: p.border, height: 28),
                      itemBuilder: (_, i) {
                        final h = list[i];
                        return InkWell(
                          onTap: () => open(h),
                          onLongPress: () => menu(h),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              padding: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(border: Border(left: BorderSide(color: p.accent, width: 2))),
                              child: Text(h.text, style: Fonts.reading(size: 16, color: p.text, height: 1.55, style: FontStyle.italic)),
                            ),
                            if (h.note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(h.note, style: Fonts.ui(size: 14, color: p.muted, height: 1.45)),
                            ],
                            const SizedBox(height: 6),
                            Row(children: [
                              Text(_date(h.createdAt), style: Fonts.ui(size: 12, color: p.faint)),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Seçenekler',
                                onPressed: () => menu(h),
                                icon: Icon(Icons.more_horiz, color: p.faint, size: 20),
                              ),
                            ]),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
