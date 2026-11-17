// Kendi sayfalama motorumuz: bir bölümü verilen ekran boyutuna ve yazı stiline göre sayfalara böler.
// Ölçüm TextPainter ile yapılır; çizim de aynı stil ve TextScaler ile RichText'le yapılır ki birebir tutsun.
import 'package:flutter/material.dart';

import '../models/book_content.dart';

class PageSlice {
  final int block; // blok indeksi
  final int start, end; // blok metninde karakter aralığı
  const PageSlice(this.block, this.start, this.end);
}

class ReaderStyle {
  final TextStyle body, verse, heading;
  final double paraGap, verseGap, headingTop, headingBottom;
  final bool justify;
  const ReaderStyle({
    required this.body,
    required this.verse,
    required this.heading,
    required this.paraGap,
    required this.verseGap,
    required this.headingTop,
    required this.headingBottom,
    required this.justify,
  });

  TextStyle styleOf(BlockKind k) => switch (k) {
        BlockKind.heading => heading,
        BlockKind.verse => verse,
        BlockKind.paragraph => body,
      };
  TextAlign alignOf(BlockKind k) => switch (k) {
        BlockKind.heading => TextAlign.center,
        BlockKind.verse => TextAlign.left,
        BlockKind.paragraph => justify ? TextAlign.justify : TextAlign.left,
      };
  double before(BlockKind k) => k == BlockKind.heading ? headingTop : 0;
  double after(BlockKind k) => switch (k) {
        BlockKind.heading => headingBottom,
        BlockKind.verse => verseGap,
        BlockKind.paragraph => paraGap,
      };
  double indentOf(BlockKind k) => k == BlockKind.verse ? 18 : 0;
}

class Paginator {
  static const scaler = TextScaler.noScaling;

  static TextPainter _painter(String text, TextStyle style, TextAlign align, double width) =>
      TextPainter(text: TextSpan(text: text, style: style), textAlign: align, textDirection: TextDirection.ltr, textScaler: scaler)
        ..layout(maxWidth: width);

  /// [ch] bölümünü [size] alanına sayfalar.
  static List<List<PageSlice>> paginate(BookContent book, Chapter ch, Size size, ReaderStyle st) {
    final pages = <List<PageSlice>>[];
    var cur = <PageSlice>[];
    var y = 0.0;
    final h = size.height - 2; // yuvarlama payı

    void newPage() {
      if (cur.isNotEmpty) pages.add(cur);
      cur = <PageSlice>[];
      y = 0;
    }

    for (var b = ch.start; b < ch.end; b++) {
      final block = book.blocks[b];
      final style = st.styleOf(block.kind);
      final align = st.alignOf(block.kind);
      final width = size.width - st.indentOf(block.kind);
      final text = block.text;
      var start = 0;
      while (start < text.length) {
        final sub = text.substring(start);
        final tp = _painter(sub, style, align, width);
        final top = cur.isEmpty ? 0.0 : st.before(block.kind);
        if (y + top + tp.height <= h) {
          cur.add(PageSlice(b, start, text.length));
          y += top + tp.height + st.after(block.kind);
          tp.dispose();
          break;
        }
        // Sığmıyor: kaç satır sığar?
        final avail = h - y - top;
        final lines = tp.computeLineMetrics();
        var fit = 0;
        var acc = 0.0;
        for (final l in lines) {
          if (acc + l.height > avail) break;
          acc += l.height;
          fit++;
        }
        final keepTogether = block.kind == BlockKind.heading;
        // Yetim satır önleme: tek satır sığıyorsa ve paragraf uzunsa yeni sayfaya geç.
        final orphan = fit == 1 && lines.length > 2;
        if (fit == 0 || keepTogether || orphan) {
          if (cur.isEmpty) {
            // Boş sayfaya bile sığmıyor (devasa punto): en az bir satır zorla.
            if (fit == 0) fit = 1;
            if (keepTogether) fit = lines.length;
          } else {
            tp.dispose();
            newPage();
            continue;
          }
        }
        if (fit >= lines.length) {
          cur.add(PageSlice(b, start, text.length));
          tp.dispose();
          newPage();
          break;
        }
        final line = lines[fit - 1];
        final yMid = line.baseline - line.ascent / 2;
        final pos = tp.getPositionForOffset(Offset(width - 1, yMid));
        var cut = tp.getLineBoundary(pos).end;
        tp.dispose();
        if (cut <= 0 || cut >= sub.length) cut = (sub.length * fit / lines.length).floor().clamp(1, sub.length - 1);
        cur.add(PageSlice(b, start, start + cut));
        newPage();
        start += cut;
        while (start < text.length && text.codeUnitAt(start) == 32) {
          start++;
        }
      }
    }
    newPage();
    if (pages.isEmpty) pages.add(const []);
    return pages;
  }
}
