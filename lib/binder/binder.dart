// Ciltleme: PDF'ten gelen görsel satırları okunabilir bloklara (başlık, paragraf, dize) çevirir.
// Saf Dart; Flutter'a bağlı değil, test edilebilir.
import 'dart:math' as math;

import '../models/book_content.dart';

/// PDF'ten çıkarılmış tek bir görsel satır. Koordinatlar PDF düzlemindedir
/// (y yukarı doğru artar; top > bottom).
class PdfLine {
  final String text;
  final double left, right, top, bottom;
  const PdfLine(this.text, this.left, this.right, this.top, this.bottom);
  double get height => (top - bottom).abs();
  bool get hasGeometry => right > left;
}

class Binder {
  static final _numberOnly = RegExp(r'^[-–—\s]*\d{1,4}[-–—\s]*$');
  static final _control = RegExp(r'[\u0000\u0001\u0003-\u0008\u000B\u000C\u000E-\u001F￾﻿]');
  static final _terminal = RegExp(r'[.!?…:;"”»)\x27’]$');
  static final _dialog = RegExp(r'^[—–]|^-\s');
  static final _heading = RegExp(
    r'^('
    r'BÖLÜM\s+([IVXLC]+|\d+|[A-ZÇĞİÖŞÜ]+)'
    r'|\d{1,3}\s*\.?\s*BÖLÜM'
    r'|(BİRİNCİ|İKİNCİ|ÜÇÜNCÜ|DÖRDÜNCÜ|BEŞİNCİ|ALTINCI|YEDİNCİ|SEKİZİNCİ|DOKUZUNCU|ONUNCU)\s+(KİTAP|BÖLÜM|KISIM)'
    r'|(KİTAP|KISIM)\s+([IVXLC]+|\d+|[A-ZÇĞİÖŞÜ]+)'
    r'|ÖNSÖZ|GİRİŞ|SONSÖZ|EKLER|EK\s+[A-Z]|PROLOG|EPİLOG'
    r')$',
  );
  static final _numberHeading = RegExp(r'^(BÖLÜM\s+\S+|\d{1,3}\s*\.?\s*BÖLÜM|\S+\s+BÖLÜM)$');

  /// Ana giriş: sayfa sayfa satırlar → bloklar.
  static List<Block> bind(List<List<PdfLine>> rawPages) {
    final cleaned = rawPages
        .map((p) => p.map(_clean).where((l) => l.text.isNotEmpty && !_numberOnly.hasMatch(l.text)).toList())
        .toList();
    final pages = _removeRunningHeaders(cleaned);
    final all = pages.expand((p) => p).toList();
    if (all.isEmpty) return const [];
    final geo = all.where((l) => l.hasGeometry).length > all.length * 0.8;
    return geo ? _bindWithGeometry(pages) : _bindTextOnly(all);
  }

  static PdfLine _clean(PdfLine l) {
    var t = l.text.replaceAll(_control, '').replaceAll('\u0002', '-').replaceAll(RegExp(r'\s+'), ' ').trim();
    t = fixTurkishMojibake(t);
    return PdfLine(t, l.left, l.right, l.top, l.bottom);
  }

  /// Eski Türkçe PDF'lerdeki Windows-1252/1254 karışıklığını onarır.
  static String fixTurkishMojibake(String s) {
    if (!s.contains(RegExp('[ýÝþÞðÐ]'))) return s;
    return s
        .replaceAll('ý', 'ı')
        .replaceAll('Ý', 'İ')
        .replaceAll('þ', 'ş')
        .replaceAll('Þ', 'Ş')
        .replaceAll('ð', 'ğ')
        .replaceAll('Ð', 'Ğ');
  }

  static bool isHeading(String t) => t.length <= 60 && _heading.hasMatch(t.toUpperCase());
  static bool _isNumberHeading(String t) => _numberHeading.hasMatch(t.toUpperCase());

  /// Her sayfanın tepesinde/dibinde tekrar eden satırları (kitap adı, yazar vb.) atar.
  static List<List<PdfLine>> _removeRunningHeaders(List<List<PdfLine>> pages) {
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\d+'), '#').trim();
    final counts = <String, int>{};
    for (final p in pages) {
      if (p.isEmpty) continue;
      for (final k in {norm(p.first.text), norm(p.last.text)}) {
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    final limit = math.max(5, (pages.length * 0.15).round());
    final running = counts.entries
        .where((e) => e.value >= limit && e.key.length < 80 && !isHeading(e.key))
        .map((e) => e.key)
        .toSet();
    if (running.isEmpty) return pages;
    return pages.map((p) {
      final out = List<PdfLine>.from(p);
      if (out.isNotEmpty && running.contains(norm(out.first.text))) out.removeAt(0);
      if (out.isNotEmpty && running.contains(norm(out.last.text))) out.removeLast();
      return out;
    }).toList();
  }

  static double _percentile(List<double> v, double p) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    return s[((s.length - 1) * p).round()];
  }

  static bool _startsLower(String t) {
    if (t.isEmpty) return false;
    final c = t[0];
    return c != c.toUpperCase() && c == c.toLowerCase();
  }

  static List<Block> _bindWithGeometry(List<List<PdfLine>> pages) {
    final all = pages.expand((p) => p).toList();
    final bodyH = _percentile(all.map((l) => l.height).toList(), 0.5);
    final blocks = <Block>[];
    final buf = <PdfLine>[];
    var bufRightEdge = true;

    void flush() {
      if (buf.isEmpty) return;
      final text = _joinLines(buf.map((l) => l.text).toList());
      final verse = buf.length == 1 && !bufRightEdge && !_terminal.hasMatch(text) && text.length < 70;
      blocks.add(Block(verse ? BlockKind.verse : BlockKind.paragraph, text));
      buf.clear();
    }

    bool lastIsOpenNumberHeading() =>
        buf.isEmpty &&
        blocks.isNotEmpty &&
        blocks.last.kind == BlockKind.heading &&
        _isNumberHeading(blocks.last.text) &&
        !blocks.last.text.contains(' · ');

    PdfLine? prev;
    double prevRight = 0, prevWidth = 1;
    for (final page in pages) {
      if (page.isEmpty) continue;
      final left = _percentile(page.map((l) => l.left).toList(), 0.1);
      final right = _percentile(page.map((l) => l.right).toList(), 0.9);
      final width = math.max(1.0, right - left);
      final dys = <double>[];
      for (var i = 1; i < page.length; i++) {
        final dy = (page[i - 1].top - page[i].top).abs();
        if (dy > 0 && dy < bodyH * 3) dys.add(dy);
      }
      final spacing = dys.isEmpty ? bodyH * 1.4 : _percentile(dys, 0.5);

      for (var i = 0; i < page.length; i++) {
        final line = page[i];
        final t = line.text;
        final big = line.height > bodyH * 1.35 && t.length < 50 && !t.endsWith(',');

        if (isHeading(t) || big) {
          flush();
          if (!isHeading(t) && lastIsOpenNumberHeading()) {
            blocks[blocks.length - 1] = Block(BlockKind.heading, '${blocks.last.text} · $t');
          } else {
            blocks.add(Block(BlockKind.heading, t));
          }
        } else if (lastIsOpenNumberHeading() && t.length < 60 && !_terminal.hasMatch(t) && t == t.toUpperCase()) {
          // Numaralı başlığın hemen altındaki büyük harfli kısa satır = bölüm adı.
          blocks[blocks.length - 1] = Block(BlockKind.heading, '${blocks.last.text} · $t');
        } else {
          bool breakBefore;
          if (buf.isEmpty) {
            breakBefore = true;
          } else if (_startsLower(t)) {
            breakBefore = false;
          } else {
            final prevShort = prev != null && prev.right < prevRight - prevWidth * 0.08;
            final indent = line.left > left + width * 0.02;
            final gap = i > 0 && prev != null && (prev.top - line.top).abs() > spacing * 1.6;
            breakBefore = prevShort || indent || gap || _dialog.hasMatch(t);
          }
          if (breakBefore) flush();
          buf.add(line);
          bufRightEdge = line.right >= right - width * 0.08;
        }
        prev = line;
        prevRight = right;
        prevWidth = width;
      }
    }
    flush();
    return blocks;
  }

  /// Konum bilgisi yoksa: yalnız metne bakarak paragraf kur.
  static List<Block> _bindTextOnly(List<PdfLine> lines) {
    final full = _percentile(lines.map((l) => l.text.length.toDouble()).toList(), 0.6);
    final blocks = <Block>[];
    final buf = <String>[];
    void flush() {
      if (buf.isEmpty) return;
      blocks.add(Block(BlockKind.paragraph, _joinLines(buf)));
      buf.clear();
    }

    for (final l in lines) {
      final t = l.text;
      if (isHeading(t)) {
        flush();
        blocks.add(Block(BlockKind.heading, t));
        continue;
      }
      if (buf.isNotEmpty) {
        final p = buf.last;
        final ended = _terminal.hasMatch(p) && p.length < full * 0.85;
        if ((ended || _dialog.hasMatch(t)) && !_startsLower(t)) flush();
      }
      buf.add(t);
    }
    flush();
    return blocks;
  }

  static String _joinLines(List<String> lines) {
    var out = lines.first;
    for (var i = 1; i < lines.length; i++) {
      final next = lines[i];
      if ((out.endsWith('-') || out.endsWith('­')) && _startsLower(next)) {
        out = out.substring(0, out.length - 1) + next;
      } else {
        out = '$out $next';
      }
    }
    return out;
  }
}
