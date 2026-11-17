// Dosyadan kitaba: PDF / EPUB / TXT okur, ciltler, BookContent döndürür.
// Taranmış (metinsiz) PDF'lerde cihaz üstü yazı tanıma (ML Kit, Latin alfabesi — Türkçe dahil) kullanılır.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

import '../models/book_content.dart';
import 'binder.dart';
import 'pdf_lines.dart';

typedef ProgressFn = void Function(int done, int total, String stage);

class Importer {
  static Future<BookContent> importFile(String path, ProgressFn onProgress) async {
    final lower = path.toLowerCase();
    if (lower.endsWith('.txt')) return _importTxt(path, onProgress);
    if (lower.endsWith('.epub')) return _importEpub(path, onProgress);
    return _importPdf(path, onProgress);
  }

  // ---------- PDF ----------

  static Future<BookContent> _importPdf(String path, ProgressFn onProgress) async {
    final doc = await PdfDocument.openFile(path);
    try {
      final n = doc.pages.length;
      var pages = <List<PdfLine>>[];
      var chars = 0;
      for (var i = 0; i < n; i++) {
        final raw = await doc.pages[i].loadText();
        final lines = raw == null ? <PdfLine>[] : linesFromRawText(raw);
        for (final l in lines) {
          chars += l.text.length;
        }
        pages.add(lines);
        if (i % 8 == 0 || i == n - 1) onProgress(i + 1, n, 'Sayfalar okunuyor');
      }
      if (chars < n * 40) {
        // Metin katmanı yok: taranmış kitap → yazı tanıma.
        pages = await _ocrPages(doc, onProgress);
      }
      onProgress(n, n, 'Paragraflar diziliyor');
      final blocks = await Isolate.run(() => Binder.bind(pages));
      return BookContent(blocks);
    } finally {
      await doc.dispose();
    }
  }

  static Future<List<List<PdfLine>>> _ocrPages(PdfDocument doc, ProgressFn onProgress) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/pagera_ocr.png');
    final out = <List<PdfLine>>[];
    try {
      final n = doc.pages.length;
      for (var i = 0; i < n; i++) {
        onProgress(i + 1, n, 'Yazı tanınıyor (taranmış kitap)');
        final page = doc.pages[i];
        // ~1400 px genişlik: hız ile doğruluk dengesi.
        final scale = 1400 / page.width;
        final w = (page.width * scale).round(), h = (page.height * scale).round();
        final img = await page.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF);
        if (img == null) {
          out.add(const []);
          continue;
        }
        final png = await _bgraToPng(img.pixels, img.width, img.height);
        img.dispose();
        await file.writeAsBytes(png);
        final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
        final lines = <PdfLine>[];
        for (final b in result.blocks) {
          for (final l in b.lines) {
            final r = l.boundingBox;
            // Görüntü koordinatı (y aşağı) → PDF düzlemi (y yukarı).
            lines.add(PdfLine(l.text, r.left, r.right, h - r.top, h - r.bottom));
          }
        }
        lines.sort((a, b) {
          final dy = b.top - a.top;
          return dy.abs() > 6 ? dy.sign.toInt() : a.left.compareTo(b.left);
        });
        out.add(lines);
      }
    } finally {
      await recognizer.close();
      if (await file.exists()) await file.delete();
    }
    return out;
  }

  static Future<List<int>> _bgraToPng(Uint8List bgra, int w, int h) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bgra);
    final desc = ui.ImageDescriptor.raw(buffer, width: w, height: h, pixelFormat: ui.PixelFormat.bgra8888);
    final codec = await desc.instantiateCodec();
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    desc.dispose();
    buffer.dispose();
    return data!.buffer.asUint8List();
  }

  // ---------- EPUB ----------

  static Future<BookContent> _importEpub(String path, ProgressFn onProgress) async {
    onProgress(0, 1, 'EPUB açılıyor');
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    String? read(String name) {
      final f = archive.findFile(name);
      return f == null ? null : utf8.decode(f.content, allowMalformed: true);
    }

    final container = read('META-INF/container.xml');
    if (container == null) throw const FormatException('Geçersiz EPUB: container.xml yok.');
    final opfPath = XmlDocument.parse(container).findAllElements('rootfile').first.getAttribute('full-path')!;
    final base = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';
    final opf = XmlDocument.parse(read(opfPath)!);
    final manifest = <String, String>{};
    for (final item in opf.findAllElements('item')) {
      final id = item.getAttribute('id'), href = item.getAttribute('href');
      if (id != null && href != null) manifest[id] = Uri.decodeFull(href);
    }
    final spine = opf.findAllElements('itemref').map((e) => manifest[e.getAttribute('idref')]).whereType<String>().toList();
    final blocks = <Block>[];
    for (var i = 0; i < spine.length; i++) {
      onProgress(i + 1, spine.length, 'Bölümler okunuyor');
      final src = read(_normalize(base + spine[i]));
      if (src == null) continue;
      final body = html.parse(src).body;
      if (body != null) _walk(body, blocks);
    }
    return BookContent(blocks);
  }

  static String _normalize(String p) {
    final parts = <String>[];
    for (final s in p.split('/')) {
      if (s == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (s.isNotEmpty && s != '.') {
        parts.add(s);
      }
    }
    return parts.join('/');
  }

  static void _walk(dom.Element el, List<Block> out) {
    for (final c in el.children) {
      final tag = c.localName;
      if (tag == null || tag == 'script' || tag == 'style') continue;
      if (RegExp(r'^h[1-6]$').hasMatch(tag)) {
        final t = _clean(c.text);
        if (t.isNotEmpty) out.add(Block(BlockKind.heading, t));
      } else if (tag == 'p' || tag == 'li') {
        // <br> ile bölünmüş kısa satırlar = şiir dizeleri.
        if (c.getElementsByTagName('br').isNotEmpty) {
          final lines = c.innerHtml.split(RegExp(r'<br\s*/?>', caseSensitive: false)).map((s) => _clean(html.parseFragment(s).text ?? '')).where((s) => s.isNotEmpty).toList();
          final verse = lines.length > 1 && lines.every((l) => l.length < 80);
          if (verse) {
            for (final l in lines) {
              out.add(Block(BlockKind.verse, l));
            }
            continue;
          }
        }
        final t = _clean(c.text);
        if (t.isNotEmpty) out.add(Block(BlockKind.paragraph, t));
      } else {
        _walk(c, out);
        // Kendi metni olan yaprak div'ler (bazı EPUB'lar <p> kullanmaz).
        if (c.children.isEmpty && (tag == 'div' || tag == 'span')) {
          final t = _clean(c.text);
          if (t.isNotEmpty) out.add(Block(BlockKind.paragraph, t));
        }
      }
    }
  }

  static String _clean(String s) => s.replaceAll('­', '').replaceAll(RegExp(r'\s+'), ' ').trim();

  // ---------- TXT ----------

  static Future<BookContent> _importTxt(String path, ProgressFn onProgress) async {
    onProgress(0, 1, 'Metin okunuyor');
    final text = await File(path).readAsString();
    final blocks = await Isolate.run(() {
      final out = <Block>[];
      for (final para in text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'))) {
        final t = para.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (t.isEmpty) continue;
        out.add(Block(Binder.isHeading(t) ? BlockKind.heading : BlockKind.paragraph, Binder.fixTurkishMojibake(t)));
      }
      return out;
    });
    onProgress(1, 1, 'Bitti');
    return BookContent(blocks);
  }

  /// Dosya adından okunaklı bir başlık tahmini.
  static String guessTitle(String path) {
    var name = path.split(RegExp(r'[\\/]')).last;
    name = name.replaceAll(RegExp(r'\.(pdf|txt|epub)$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'([_-]\d{3,})+$'), '');
    name = name.replaceAll(RegExp(r'[_\-.]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return name.isEmpty ? 'Adsız kitap' : name;
  }
}
