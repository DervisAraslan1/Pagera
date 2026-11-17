// EPUB okuma testi (yapay, küçük bir EPUB üretip okur; gerçek kitap kullanılmaz).
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagera/binder/importer.dart';
import 'package:pagera/models/book_content.dart';
import 'package:pagera/reader/highlight_sheet.dart';

void main() {
  test('EPUB: omurga sırası, başlık, paragraf ve şiir dizeleri', () async {
    ArchiveFile f(String name, String text) {
      final b = utf8.encode(text);
      return ArchiveFile(name, b.length, b);
    }

    final archive = Archive()
      ..addFile(f('mimetype', 'application/epub+zip'))
      ..addFile(f('META-INF/container.xml',
          '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'))
      ..addFile(f('OEBPS/content.opf',
          '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0"><manifest><item id="c2" href="Text/iki.xhtml" media-type="application/xhtml+xml"/><item id="c1" href="Text/bir.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="c1"/><itemref idref="c2"/></spine></package>'))
      ..addFile(f('OEBPS/Text/bir.xhtml',
          '<html><body><h1>Birinci Bölüm</h1><p>Çok güzel bir gün&nbsp;başladı. Ağaçlar ışıldıyordu.</p><p>Kısa dize bir<br/>kısa dize iki</p></body></html>'))
      ..addFile(f('OEBPS/Text/iki.xhtml', '<html><body><h2>İkinci Bölüm</h2><div><p>Son paragraf.</p></div></body></html>'));
    final tmp = File('${Directory.systemTemp.path}/pagera_test.epub');
    await tmp.writeAsBytes(ZipEncoder().encode(archive));

    final c = await Importer.importFile(tmp.path, (_, _, _) {});
    final kinds = c.blocks.map((b) => b.kind).toList();
    expect(c.blocks.first.text, 'Birinci Bölüm');
    expect(kinds, [BlockKind.heading, BlockKind.paragraph, BlockKind.verse, BlockKind.verse, BlockKind.heading, BlockKind.paragraph]);
    expect(c.blocks[1].text, 'Çok güzel bir gün başladı. Ağaçlar ışıldıyordu.');
    expect(c.chapters.length, 2);
    await tmp.delete();
  });

  test('cümle bölme', () {
    final s = splitSentences('Bir. İki! "Üç?" dedi. Dört');
    expect(s.length, 4);
    expect('Bir. İki! "Üç?" dedi. Dört'.substring(s[2].$1, s[2].$2).trim(), '"Üç?" dedi.');
  });
}
