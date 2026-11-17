// Ciltleme ve sayfalama testleri (yapay metinle; gerçek kitap metni kullanılmaz).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagera/binder/binder.dart';
import 'package:pagera/models/book_content.dart';
import 'package:pagera/reader/paginator.dart';

PdfLine line(String t, double y, {double left = 72, double right = 540}) => PdfLine(t, left, right, y, y - 12);

void main() {
  group('Binder', () {
    test('satır sonu tiresi birleşir, paragraf sayfa geçişinde devam eder', () {
      final pages = [
        [
          line('BÖLÜM I', 700, left: 280, right: 330),
          line('Birinci paragrafın ilk satırı burada uzunca devam ediyor ve keli-', 670),
          line('meyi bölüyor; cümle sürüyor ve sayfa sonuna kadar gidiyor bu', 655),
        ],
        [
          line('satır ise yeni sayfada aynı paragrafa ait olmalı ve kısa biter.', 700, right: 400),
          line('İkinci paragraf girintiyle başlar ve tam genişlikte devam eder', 685, left: 90),
          line('ve noktayla biter.', 670, right: 200),
        ],
      ];
      final b = Binder.bind(pages);
      expect(b.first.kind, BlockKind.heading);
      final paras = b.where((x) => x.kind == BlockKind.paragraph).toList();
      expect(paras.length, 2);
      expect(paras[0].text.contains('kelimeyi'), isTrue);
      expect(paras[0].text.contains('bu satır ise'), isTrue);
      expect(paras[1].text.startsWith('İkinci'), isTrue);
    });

    test('bölüm adı numaralı başlığa eklenir, sayfa numarası atılır', () {
      final pages = [
        [
          line('BÖLÜM IV', 700, left: 280, right: 330),
          line('UZUN BİR YOLCULUK', 680, left: 230, right: 380),
          line('Metin burada başlıyor ve tam satır boyunca devam ediyor işte', 650),
          line('böyle bitiyor.', 635, right: 200),
          line('12', 60, left: 300, right: 312),
        ],
      ];
      final b = Binder.bind(pages);
      expect(b.first.text, 'BÖLÜM IV · UZUN BİR YOLCULUK');
      expect(b.any((x) => x.text == '12'), isFalse);
    });

    test('bozuk Türkçe karakterler onarılır', () {
      expect(Binder.fixTurkishMojibake('ýþýk aðaç Ýstanbul'), 'ışık ağaç İstanbul');
    });
  });

  group('Paginator', () {
    testWidgets('her karakter tam bir kez, sırayla sayfalara dağılır ve sayfaya sığar', (tester) async {
      final words = List.generate(40, (i) => 'kelime$i');
      final blocks = <Block>[const Block(BlockKind.heading, 'BÖLÜM I')];
      for (var i = 0; i < 60; i++) {
        blocks.add(Block(BlockKind.paragraph, List.generate(20 + i % 30, (j) => words[(i + j) % words.length]).join(' ')));
        if (i % 9 == 0) blocks.add(const Block(BlockKind.verse, 'kısa bir dize burada'));
      }
      final book = BookContent(blocks);
      const st = ReaderStyle(
        body: TextStyle(fontSize: 18, height: 1.7),
        verse: TextStyle(fontSize: 17, height: 1.5, fontStyle: FontStyle.italic),
        heading: TextStyle(fontSize: 24, height: 1.25),
        paraGap: 10,
        verseGap: 2,
        headingTop: 36,
        headingBottom: 26,
        justify: true,
      );
      const size = Size(330, 600);
      final pages = Paginator.paginate(book, book.chapters.first, size, st);
      expect(pages.length, greaterThan(3));

      // Kapsama: blok blok, aralıklar ardışık ve tam.
      final covered = <int, int>{};
      for (final p in pages) {
        for (final s in p) {
          final prevEnd = covered[s.block] ?? 0;
          final gap = book.blocks[s.block].text.substring(prevEnd, s.start);
          expect(gap.trim(), isEmpty, reason: 'blok ${s.block} atlanan metin');
          covered[s.block] = s.end;
        }
      }
      for (var i = 0; i < blocks.length; i++) {
        expect(covered[i], blocks[i].text.length, reason: 'blok $i eksik');
      }

      // Taşma: her sayfanın ölçülen yüksekliği alana sığmalı.
      for (final p in pages) {
        var y = 0.0;
        for (var i = 0; i < p.length; i++) {
          final s = p[i];
          final b = book.blocks[s.block];
          if (i > 0) y += st.before(b.kind);
          final tp = TextPainter(
            text: TextSpan(text: b.text.substring(s.start, s.end), style: st.styleOf(b.kind)),
            textAlign: st.alignOf(b.kind),
            textDirection: TextDirection.ltr,
            textScaler: Paginator.scaler,
          )..layout(maxWidth: size.width - st.indentOf(b.kind));
          y += tp.height;
          tp.dispose();
          if (i < p.length - 1) y += st.after(b.kind);
        }
        expect(y, lessThanOrEqualTo(size.height));
      }
    });
  });
}
