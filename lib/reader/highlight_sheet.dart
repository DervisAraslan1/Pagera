// Paragrafa uzun basınca açılan panel: cümle seç → altını çiz, istersen not ekle.
import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../theme/palettes.dart';

/// Paragrafı cümlelere böler: [başlangıç, bitiş) aralıkları.
List<(int, int)> splitSentences(String t) {
  final out = <(int, int)>[];
  final re = RegExp(r'[.!?…]+["”»\x27’)]*\s+');
  var start = 0;
  for (final m in re.allMatches(t)) {
    // "...?" dedi. → küçük harfle devam ediyorsa aynı cümle.
    if (m.end < t.length) {
      final c = t[m.end];
      if (c != c.toUpperCase() && c == c.toLowerCase()) continue;
    }
    out.add((start, m.end));
    start = m.end;
  }
  if (start < t.length) out.add((start, t.length));
  return out;
}

Future<void> showHighlightSheet(BuildContext context, Book book, int block, String text) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _HighlightSheet(book: book, block: block, text: text),
  );
}

class _HighlightSheet extends StatefulWidget {
  final Book book;
  final int block;
  final String text;
  const _HighlightSheet({required this.book, required this.block, required this.text});
  @override
  State<_HighlightSheet> createState() => _HighlightSheetState();
}

class _HighlightSheetState extends State<_HighlightSheet> {
  late final sentences = splitSentences(widget.text);
  final Set<int> _picked = {};

  Future<void> _save({required bool withNote}) async {
    final store = AppScope.read(context);
    final idx = _picked.toList()..sort();
    final start = sentences[idx.first].$1;
    var end = sentences[idx.last].$2;
    while (end > start && widget.text.codeUnitAt(end - 1) == 32) {
      end--; // sondaki boşluk vurguya girmesin
    }
    var note = '';
    if (withNote) {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not'),
          content: TextField(controller: c, autofocus: true, maxLines: 4, decoration: const InputDecoration(hintText: 'Aklından geçeni yaz')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      );
      if (ok != true) return;
      note = c.text.trim();
    }
    store.addHighlight(Highlight(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      bookId: widget.book.id,
      block: widget.block,
      start: start,
      end: end,
      text: widget.text.substring(start, end).trim(),
      note: note,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.palette;
    final existing = store.highlights.where((h) => h.bookId == widget.book.id && h.block == widget.block).toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ALTINI ÇİZ', style: Fonts.label(p.muted)),
            const SizedBox(height: 6),
            Text('Cümlelere dokunarak seç.', style: Fonts.ui(size: 13, color: p.faint)),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text.rich(
                  TextSpan(children: [
                    for (var i = 0; i < sentences.length; i++)
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => setState(() => _picked.contains(i) ? _picked.remove(i) : _picked.add(i)),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: _picked.contains(i) ? p.accent.withValues(alpha: 0.32) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.text.substring(sentences[i].$1, sentences[i].$2),
                              style: Fonts.reading(size: 16, color: p.text, height: 1.6),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
            if (existing.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final h in existing)
                Row(children: [
                  Icon(Icons.format_quote, size: 18, color: p.accent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(h.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.ui(size: 13, color: p.muted))),
                  TextButton(
                    onPressed: () {
                      store.removeHighlight(h);
                      setState(() {});
                    },
                    child: const Text('Kaldır'),
                  ),
                ]),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _picked.isEmpty ? null : () => _save(withNote: false),
                  child: const Text('Altını çiz'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.text,
                    minimumSize: const Size(0, 50),
                    side: BorderSide(color: p.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _picked.isEmpty ? null : () => _save(withNote: true),
                  child: const Text('Not ekle'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
