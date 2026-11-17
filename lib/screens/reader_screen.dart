// Okuma ekranı: kendi sayfalama motorumuzla, kâğıt/sepya/gece sayfa, odak sayacı.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/library_store.dart';
import '../models/book_content.dart';
import '../reader/highlight_sheet.dart';
import '../reader/paginator.dart';
import '../theme/palettes.dart';
import '../widgets/shelf_widgets.dart';

class ReaderScreen extends StatefulWidget {
  final String bookId;
  final int? focusMinutes;
  final int? startAt; // notlardan atlama: bu karakter ofsetinden aç
  const ReaderScreen({super.key, required this.bookId, this.focusMinutes, this.startAt});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with WidgetsBindingObserver {
  late final LibraryStore _store = AppScope.read(context);
  late final Book _book = _store.byId(widget.bookId)!;
  BookContent? _content;
  bool _fontsReady = false;

  int _chapter = 0, _page = 0;
  int _pos = 0; // geçerli sayfanın başlangıç ofseti
  int _dir = 1; // animasyon yönü
  bool _chrome = true;
  bool _focusDone = false;

  String _sig = '';
  final Map<int, List<List<PageSlice>>> _pages = {};
  ReaderStyle? _style;

  final Stopwatch _watch = Stopwatch();
  int _sessionStartPos = 0;
  late final int _sessionStart = DateTime.now().millisecondsSinceEpoch;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _stayAwake();
    _load();
  }

  Future<void> _load() async {
    final c = await _store.content(_book);
    try {
      Fonts.reading();
      Fonts.reading(style: FontStyle.italic);
      Fonts.display();
      await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 6));
    } catch (_) {
      // Çevrimdışı ve önbellekte yok: yedek yazı tipiyle devam (ölçüm ve çizim aynı kalır).
    }
    if (!mounted) return;
    _pos = (widget.startAt ?? _book.position).clamp(0, c.totalChars);
    _sessionStartPos = _pos;
    setState(() {
      _content = c;
      _fontsReady = true;
    });
    _watch.start();
    // Pil: sayfa her saniye yeniden çizilmez; yalnız odak hedefini 15 sn'de bir kontrol et.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final goal = widget.focusMinutes;
      if (goal != null && !_focusDone && _watch.elapsed.inMinutes >= goal) {
        _focusDone = true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$goal dakika tamam. Güzel gidiyorsun!')));
      }
    });
  }

  /// Pil: ekranı sürekli açık tutma; son dokunuştan 5 dk sonra telefonun kendi ekran zaman aşımına bırak.
  Timer? _awake;
  void _stayAwake() {
    WakelockPlus.enable();
    _awake?.cancel();
    // Ayarlarda "Ekranı açık tut" açıksa okuyucu kapanana kadar ekran kararmaz.
    if (_store.settings.keepScreenOn) return;
    _awake = Timer(const Duration(minutes: 5), WakelockPlus.disable);
  }

  Future<void> _highlightBlock(int block) async {
    _stayAwake();
    await showHighlightSheet(context, _book, block, _content!.blocks[block].text);
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watch.start();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _watch.stop();
      _persist();
    }
  }

  void _persist() {
    if (_content != null) _store.savePosition(_book, _pos);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _awake?.cancel();
    _watch.stop();
    if (_content != null) {
      _store.savePosition(_book, _pos);
      _store.addSession(ReadingSession(_book.id, _sessionStart, _watch.elapsed.inSeconds, (_pos - _sessionStartPos).clamp(0, 1 << 30)));
    }
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ---- Sayfalama ----

  ReaderStyle _buildStyle(PagePalette pp) {
    final s = _store.settings;
    final body = Fonts.reading(size: s.fontSize, color: pp.text);
    return ReaderStyle(
      body: body,
      verse: Fonts.reading(size: s.fontSize * 0.94, color: pp.text, style: FontStyle.italic, height: 1.55),
      heading: Fonts.display(size: s.fontSize * 1.3, color: pp.accent, height: 1.25),
      paraGap: s.fontSize * 0.55,
      verseGap: 2,
      headingTop: s.fontSize * 2,
      headingBottom: s.fontSize * 1.4,
      justify: s.justify,
    );
  }

  int _blockAt(int pos) {
    final o = _content!.offsets;
    var lo = 0, hi = o.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (o[mid] <= pos) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  List<List<PageSlice>> _pagesOf(int ch, Size size) =>
      _pages.putIfAbsent(ch, () => Paginator.paginate(_content!, _content!.chapters[ch], size, _style!));

  int _offsetOf(PageSlice s) => _content!.offsets[s.block] + s.start;

  void _locate(Size size) {
    final c = _content!;
    if (c.blocks.isEmpty) return;
    final block = _blockAt(_pos);
    _chapter = c.chapterIndexOfBlock(block);
    final pages = _pagesOf(_chapter, size);
    _page = 0;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].isEmpty) continue;
      if (_offsetOf(pages[i].first) <= _pos) _page = i;
    }
  }

  void _go(int delta, Size size) {
    _stayAwake();
    final c = _content!;
    var ch = _chapter, pg = _page + delta;
    if (pg >= _pagesOf(ch, size).length) {
      if (ch + 1 >= c.chapters.length) {
        _finishedDialog();
        return;
      }
      ch++;
      pg = 0;
    } else if (pg < 0) {
      if (ch == 0) return;
      ch--;
      pg = _pagesOf(ch, size).length - 1;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _dir = delta;
      _chapter = ch;
      _page = pg;
      final first = _pagesOf(ch, size)[pg];
      if (first.isNotEmpty) _pos = _offsetOf(first.first);
    });
    _persist();
    // Komşu bölümü önceden hazırla.
    if (ch + 1 < c.chapters.length) _pagesOf(ch + 1, size);
  }

  void _jumpToChapter(int ch) {
    setState(() {
      _pos = _content!.offsets[_content!.chapters[ch].start];
      _sig = ''; // yeniden konumla
    });
    _persist();
  }

  Future<void> _finishedDialog() async {
    _pos = _content!.totalChars;
    _persist();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kitap bitti'),
        content: Text('“${_book.title}” Bitirdiklerim rafına kondu.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Harika'))],
      ),
    );
  }

  // ---- Arayüz ----

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final pp = PagePalette.of(store.effectivePageMode());
    final content = _content;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: pp.mode == PageMode.kagit || pp.mode == PageMode.sepya ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: pp.bg,
        body: content == null || !_fontsReady
            ? Center(child: CircularProgressIndicator(color: pp.accent))
            : LayoutBuilder(builder: (context, box) => _buildReader(context, box, pp, content)),
      ),
    );
  }

  Widget _buildReader(BuildContext context, BoxConstraints box, PagePalette pp, BookContent c) {
    final pad = MediaQuery.paddingOf(context);
    const hPad = 28.0;
    final top = pad.top + 62, bottom = pad.bottom + 54;
    final size = Size(box.maxWidth - hPad * 2, box.maxHeight - top - bottom);
    final s = _store.settings;
    final sig = '${size.width.round()}x${size.height.round()}|${s.fontSize}|${s.justify}|${pp.mode.name}';
    if (sig != _sig) {
      _sig = sig;
      _pages.clear();
      _style = _buildStyle(pp);
      _locate(size);
    }
    if (c.blocks.isEmpty) return Center(child: Text('Boş kitap', style: Fonts.ui(color: pp.muted)));
    final pages = _pagesOf(_chapter, size);
    _page = _page.clamp(0, pages.length - 1);
    final chapter = c.chapters[_chapter];
    final chEnd = c.offsets[chapter.end - 1] + c.blocks[chapter.end - 1].text.length;
    final leftMin = ((chEnd - _pos) / _store.charsPerMinute()).ceil();
    final progress = c.totalChars == 0 ? 0.0 : _pos / c.totalChars;

    return Stack(children: [
      // Sayfa
      Positioned(
        left: hPad,
        right: hPad,
        top: top,
        bottom: bottom,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) {
            final incoming = child.key == ValueKey('$_chapter-$_page');
            final dx = (incoming ? 0.06 : -0.06) * _dir;
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim), child: child),
            );
          },
          child: _PageView(
            key: ValueKey('$_chapter-$_page'),
            book: c,
            slices: pages[_page],
            style: _style!,
            highlights: _store.highlightsFor(_book.id),
            mark: pp.highlight,
            onLongPress: _highlightBlock,
          ),
        ),
      ),
      // Dokunma alanları
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) {
            final x = d.localPosition.dx / box.maxWidth;
            if (x < 0.3) {
              _go(-1, size);
            } else if (x > 0.7) {
              _go(1, size);
            } else {
              _stayAwake();
              setState(() => _chrome = !_chrome);
            }
          },
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -150) _go(1, size);
            if (v > 150) _go(-1, size);
          },
        ),
      ),
      // Üst çubuk
      Positioned(
        left: 8,
        right: 8,
        top: pad.top + 6,
        child: AnimatedOpacity(
          opacity: _chrome ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_chrome,
            child: Row(children: [
              IconButton(
                tooltip: 'Kitabı kapat',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: pp.muted),
              ),
              const Spacer(),
              _TimerChip(watch: _watch, goal: widget.focusMinutes, pp: pp, active: _chrome),
              const Spacer(),
              IconButton(tooltip: 'İçindekiler', onPressed: () => _showToc(pp), icon: Icon(Icons.toc, color: pp.muted)),
              TextButton(
                onPressed: () => _showSettings(),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text('Aa', style: Fonts.reading(size: 17, color: pp.accent, height: 1)),
              ),
            ]),
          ),
        ),
      ),
      // Alt bilgi
      Positioned(
        left: 26,
        right: 26,
        bottom: pad.bottom + 16,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: _chrome ? 1 : 0.35,
            duration: const Duration(milliseconds: 200),
            child: Column(children: [
              ProgressLine(value: progress, color: pp.accent, track: pp.text.withValues(alpha: 0.1), height: 2),
              const SizedBox(height: 8),
              Row(children: [
                Text('%${(progress * 100).toStringAsFixed(progress < 0.1 ? 1 : 0)}', style: Fonts.ui(size: 12, color: pp.muted)),
                const Spacer(),
                Text(leftMin <= 1 ? 'Bölüm bitiyor' : 'Bölüm sonuna $leftMin dk', style: Fonts.ui(size: 12, color: pp.muted)),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }

  void _showToc(PagePalette pp) {
    final c = _content!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pp.chrome,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, sc) => ListView.builder(
          controller: sc,
          itemCount: c.chapters.length,
          itemBuilder: (ctx, i) => ListTile(
            selected: i == _chapter,
            selectedColor: pp.accent,
            textColor: pp.text,
            title: Text(c.chapters[i].title, style: Fonts.reading(size: 16, height: 1.3, color: i == _chapter ? pp.accent : pp.text)),
            onTap: () {
              Navigator.pop(ctx);
              _jumpToChapter(i);
            },
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _ReaderSettingsSheet(onChanged: () => setState(() => _sig = '')),
    );
  }
}

class _PageView extends StatelessWidget {
  final BookContent book;
  final List<PageSlice> slices;
  final ReaderStyle style;
  final List<Highlight> highlights;
  final Color mark;
  final void Function(int block) onLongPress;
  const _PageView({
    super.key,
    required this.book,
    required this.slices,
    required this.style,
    required this.highlights,
    required this.mark,
    required this.onLongPress,
  });

  /// Dilimi altı çizili aralıklara göre parçalara ayırır (ölçüyü değiştirmez, sadece zemin rengi).
  TextSpan _span(PageSlice s, Block b) {
    final base = style.styleOf(b.kind);
    final marks = highlights.where((h) => h.block == s.block && h.end > s.start && h.start < s.end).toList();
    if (marks.isEmpty) return TextSpan(text: b.text.substring(s.start, s.end), style: base);
    final parts = <TextSpan>[];
    var at = s.start;
    for (final h in marks) {
      final hs = h.start.clamp(s.start, s.end), he = h.end.clamp(s.start, s.end);
      if (hs > at) parts.add(TextSpan(text: b.text.substring(at, hs)));
      if (he > hs && he > at) parts.add(TextSpan(text: b.text.substring(hs < at ? at : hs, he), style: TextStyle(backgroundColor: mark)));
      if (he > at) at = he;
    }
    if (at < s.end) parts.add(TextSpan(text: b.text.substring(at, s.end)));
    return TextSpan(style: base, children: parts);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < slices.length; i++) {
      final s = slices[i];
      final b = book.blocks[s.block];
      if (i > 0 && style.before(b.kind) > 0) children.add(SizedBox(height: style.before(b.kind)));
      children.add(GestureDetector(
        onLongPress: b.kind == BlockKind.heading ? null : () => onLongPress(s.block),
        child: Padding(
          padding: EdgeInsets.only(left: style.indentOf(b.kind)),
          child: RichText(
            textScaler: Paginator.scaler,
            textAlign: style.alignOf(b.kind),
            text: _span(s, b),
          ),
        ),
      ));
      children.add(SizedBox(height: style.after(b.kind)));
    }
    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

/// Sadece kendini yeniler (sayfa değil); üst çubuk gizliyken hiç çalışmaz.
class _TimerChip extends StatefulWidget {
  final Stopwatch watch;
  final int? goal;
  final PagePalette pp;
  final bool active;
  const _TimerChip({required this.watch, required this.goal, required this.pp, required this.active});
  @override
  State<_TimerChip> createState() => _TimerChipState();
}

class _TimerChipState extends State<_TimerChip> {
  Timer? _t;

  void _sync() {
    _t?.cancel();
    _t = widget.active ? Timer.periodic(const Duration(seconds: 1), (_) => setState(() {})) : null;
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_TimerChip old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final pp = widget.pp;
    final e = widget.watch.elapsed;
    String two(int n) => n.toString().padLeft(2, '0');
    String label;
    if (goal != null) {
      final left = Duration(minutes: goal) - e;
      label = left.isNegative ? 'Hedef tamam · ${two(e.inMinutes)}:${two(e.inSeconds % 60)}' : 'Odak · ${two(left.inMinutes)}:${two(left.inSeconds % 60)}';
    } else {
      label = '${two(e.inMinutes)}:${two(e.inSeconds % 60)}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: pp.chrome, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(pp.mode == PageMode.gece ? Icons.dark_mode_outlined : Icons.timer_outlined, size: 14, color: pp.muted),
        const SizedBox(width: 6),
        Text(label, style: Fonts.ui(size: 13, weight: FontWeight.w500, color: pp.muted)),
      ]),
    );
  }
}

class _ReaderSettingsSheet extends StatefulWidget {
  final VoidCallback onChanged;
  const _ReaderSettingsSheet({required this.onChanged});
  @override
  State<_ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<_ReaderSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final p = store.palette;
    void apply(VoidCallback f) {
      setState(f);
      store.changed();
      widget.onChanged();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SAYFA', style: Fonts.label(p.muted)),
          const SizedBox(height: 10),
          Row(children: [
            for (final pg in PagePalette.all) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => apply(() {
                    s.pageMode = pg.mode;
                    // Elle seçilen sayfa, gece otomatiği yüzünden görünmüyorsa otomatiği kapat.
                    if (store.effectivePageMode() != pg.mode) s.autoNight = false;
                  }),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: pg.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: store.effectivePageMode() == pg.mode ? p.accent : p.border,
                        width: store.effectivePageMode() == pg.mode ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(pg.name, style: Fonts.ui(size: 13, weight: FontWeight.w500, color: pg.text)),
                  ),
                ),
              ),
              if (pg != PagePalette.all.last) const SizedBox(width: 10),
            ],
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Text('A', style: Fonts.reading(size: 14, color: p.muted)),
            Expanded(
              child: Slider(
                min: 14,
                max: 28,
                divisions: 14,
                value: s.fontSize,
                label: s.fontSize.round().toString(),
                onChanged: (v) => apply(() => s.fontSize = v),
              ),
            ),
            Text('A', style: Fonts.reading(size: 22, color: p.text)),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('İki yana yasla', style: Fonts.ui(size: 15, color: p.text)),
            value: s.justify,
            onChanged: (v) => apply(() => s.justify = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Akşam olunca gece sayfası', style: Fonts.ui(size: 15, color: p.text)),
            subtitle: Text('20:00 – 07:00 arası siyah sayfa', style: Fonts.ui(size: 12, color: p.muted)),
            value: s.autoNight,
            onChanged: (v) => apply(() => s.autoNight = v),
          ),
        ]),
      ),
    );
  }
}
