// Geliştirme aracı: bir PDF'in pdfrx (PDFium) ile nasıl metin verdiğini ölçer.
// Kitap metnini YAZDIRMAZ, sadece istatistik verir.
// Kullanım: dart run tool/inspect_pdf.dart <dosya.pdf>
import 'dart:io';

import 'package:pdfrx_engine/pdfrx_engine.dart';

Future<void> main(List<String> args) async {
  await pdfrxInitialize();
  final doc = await PdfDocument.openFile(args.first);
  var chars = 0, crlf = 0, lf = 0, rectsOk = 0, pagesWithText = 0;
  final lineLens = <int>[];
  for (final page in doc.pages.take(60)) {
    final raw = await page.loadText();
    if (raw == null) continue;
    final t = raw.fullText;
    chars += t.length;
    if (t.trim().isNotEmpty) pagesWithText++;
    crlf += '\r\n'.allMatches(t).length;
    lf += '\n'.allMatches(t).length;
    if (raw.charRects.length == t.length) rectsOk++;
    for (final l in t.split(RegExp(r'\r?\n'))) {
      if (l.trim().isNotEmpty) lineLens.add(l.trim().length);
    }
  }
  lineLens.sort();
  const tr = 'ıİşŞğĞçÇöÖüÜ';
  final sample = (await doc.pages[30].loadText())!.fullText;
  final trCount = sample.split('').where(tr.contains).length;
  stdout.writeln('sayfa: ${doc.pages.length}, ilk 60 sayfada karakter: $chars, metinli sayfa: $pagesWithText');
  stdout.writeln('CRLF: $crlf, LF: $lf, charRects==metin uzunluğu olan sayfa: $rectsOk');
  stdout.writeln('satır: ${lineLens.length}, medyan satır uzunluğu: ${lineLens[lineLens.length ~/ 2]}');
  stdout.writeln('31. sayfada Türkçe harf sayısı: $trCount, U+FFFD: ${'�'.allMatches(sample).length}');
  final p = doc.pages[30];
  stdout.writeln('sayfa boyutu: ${p.width} x ${p.height}');
  await doc.dispose();
}
