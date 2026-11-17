// Geliştirme aracı: PDF'i uygulamanın ciltleme koduyla işler, kalite ölçümü yazar.
// Kitap metnini YAZDIRMAZ.
// Kullanım: dart run tool/bind_pdf.dart <dosya.pdf>
import 'dart:io';

import 'package:pagera/binder/binder.dart';
import 'package:pagera/binder/pdf_lines.dart';
import 'package:pagera/models/book_content.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

Future<void> main(List<String> args) async {
  await pdfrxInitialize();
  final doc = await PdfDocument.openFile(args.first);
  final sw = Stopwatch()..start();
  final pages = <List<PdfLine>>[];
  for (final p in doc.pages) {
    final raw = await p.loadText();
    pages.add(raw == null ? [] : linesFromRawText(raw));
  }
  final tExtract = sw.elapsedMilliseconds;
  final blocks = Binder.bind(pages);
  final tBind = sw.elapsedMilliseconds - tExtract;
  final content = BookContent(blocks);
  final terminal = RegExp(r'[.!?…:;"”»)\x27’]$');
  final paras = blocks.where((b) => b.kind == BlockKind.paragraph).toList();
  final lens = paras.map((b) => b.text.length).toList()..sort();
  stdout.writeln('çıkarma: ${tExtract}ms, ciltleme: ${tBind}ms');
  stdout.writeln('başlık: ${blocks.where((b) => b.kind == BlockKind.heading).length}, '
      'paragraf: ${paras.length}, dize: ${blocks.where((b) => b.kind == BlockKind.verse).length}');
  stdout.writeln('bölüm (sayfalama birimi): ${content.chapters.length}, toplam karakter: ${content.totalChars}');
  stdout.writeln('medyan paragraf: ${lens[lens.length ~/ 2]}, en uzun: ${lens.last}');
  stdout.writeln('küçük harfle başlayan paragraf: ${paras.where((b) => RegExp(r'^[a-zçğıöşü]').hasMatch(b.text)).length}');
  stdout.writeln('noktalamasız biten paragraf: ${paras.where((b) => !terminal.hasMatch(b.text)).length}');
  stdout.writeln('içinde tire+boşluk kalan (birleşmemiş heceleme şüphesi): '
      '${paras.where((b) => RegExp(r'[a-zçğıöşü]- [a-zçğıöşü]').hasMatch(b.text)).length}');
  final hs = content.chapters.map((c) => c.title.length > 18 ? '${c.title.substring(0, 18)}…' : c.title).take(12);
  stdout.writeln('ilk bölüm başlıkları: ${hs.join(' | ')}');
  await doc.dispose();
}
