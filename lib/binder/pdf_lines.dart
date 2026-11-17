// pdfrx ham metnini (karakter kutularıyla) görsel satırlara böler.
import 'package:pdfrx_engine/pdfrx_engine.dart';

import 'binder.dart';

List<PdfLine> linesFromRawText(PdfPageRawText raw) {
  final t = raw.fullText;
  final rects = raw.charRects;
  final hasRects = rects.length == t.length;
  final out = <PdfLine>[];

  void emit(int s, int e) {
    if (e <= s) return;
    final text = t.substring(s, e);
    if (text.trim().isEmpty) return;
    if (!hasRects) {
      out.add(PdfLine(text, 0, 0, 0, 0));
      return;
    }
    double l = double.infinity, r = -double.infinity, top = -double.infinity, bottom = double.infinity;
    for (var i = s; i < e; i++) {
      final ch = t.codeUnitAt(i);
      if (ch == 32 || ch == 9) continue;
      final rc = rects[i];
      if (rc.right <= rc.left) continue;
      if (rc.left < l) l = rc.left;
      if (rc.right > r) r = rc.right;
      final hi = rc.top > rc.bottom ? rc.top : rc.bottom;
      final lo = rc.top > rc.bottom ? rc.bottom : rc.top;
      if (hi > top) top = hi;
      if (lo < bottom) bottom = lo;
    }
    if (l == double.infinity) {
      out.add(PdfLine(text, 0, 0, 0, 0));
    } else {
      out.add(PdfLine(text, l, r, top, bottom));
    }
  }

  var start = 0;
  for (var i = 0; i < t.length; i++) {
    final c = t.codeUnitAt(i);
    if (c == 10 || c == 13) {
      emit(start, i);
      if (c == 13 && i + 1 < t.length && t.codeUnitAt(i + 1) == 10) i++;
      start = i + 1;
    }
  }
  emit(start, t.length);
  return out;
}
