// Uygulamanın tek durum kaynağı: kitaplar, okuma oturumları, ayarlar.
// Kalıcılık: uygulama belgeler klasöründe state.json + books/<id>.json (içerik).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../models/book_content.dart';
import '../theme/palettes.dart';

class Book {
  final String id;
  String title, author;
  final int totalChars;
  final int addedAt;
  int? lastReadAt;
  int position; // kitap başından karakter ofseti
  bool finished;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.totalChars,
    required this.addedAt,
    this.lastReadAt,
    this.position = 0,
    this.finished = false,
  });

  double get progress => totalChars == 0 ? 0 : (position / totalChars).clamp(0.0, 1.0);
  bool get started => position > 0 || lastReadAt != null;

  Map<String, Object?> toJson() => {
        'id': id, 'title': title, 'author': author, 'totalChars': totalChars, 'addedAt': addedAt,
        'lastReadAt': lastReadAt, 'position': position, 'finished': finished,
      };
  static Book fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        author: (j['author'] as String?) ?? '',
        totalChars: j['totalChars'] as int,
        addedAt: j['addedAt'] as int,
        lastReadAt: j['lastReadAt'] as int?,
        position: (j['position'] as int?) ?? 0,
        finished: (j['finished'] as bool?) ?? false,
      );
}

class ReadingSession {
  final String bookId;
  final int start; // epoch ms
  final int seconds;
  final int chars; // bu oturumda ilerlenen karakter
  const ReadingSession(this.bookId, this.start, this.seconds, this.chars);
  Map<String, Object> toJson() => {'b': bookId, 's': start, 'd': seconds, 'c': chars};
  static ReadingSession fromJson(Map<String, dynamic> j) =>
      ReadingSession(j['b'] as String, j['s'] as int, j['d'] as int, j['c'] as int);
}

/// Altı çizili bölüm (+ isteğe bağlı not). [block]/[start]/[end] kitap içeriğinde konum.
class Highlight {
  final String id, bookId;
  final int block, start, end;
  final String text;
  String note;
  final int createdAt;
  Highlight({
    required this.id,
    required this.bookId,
    required this.block,
    required this.start,
    required this.end,
    required this.text,
    this.note = '',
    required this.createdAt,
  });
  Map<String, Object> toJson() =>
      {'id': id, 'b': bookId, 'k': block, 's': start, 'e': end, 't': text, 'n': note, 'c': createdAt};
  static Highlight fromJson(Map<String, dynamic> j) => Highlight(
        id: j['id'] as String,
        bookId: j['b'] as String,
        block: j['k'] as int,
        start: j['s'] as int,
        end: j['e'] as int,
        text: j['t'] as String,
        note: (j['n'] as String?) ?? '',
        createdAt: j['c'] as int,
      );
}

class Settings {
  bool keepScreenOn = false; // okuyucu açıkken ekran hiç kararmasın
  AppThemeId theme = AppThemeId.gece;
  PageMode pageMode = PageMode.kagit;
  bool autoNight = true; // 20:00–07:00 arası gece sayfası
  double fontSize = 17;
  bool justify = false; // Türkçe heceleme olmadan iki yana yaslama dar ekranda geniş boşluk açıyor
  int dailyGoalMin = 20;
  bool reminderOn = false;
  int reminderMinutes = 21 * 60; // günün dakikası
  bool interceptOn = false; // dürtü kesme (Android kullanım erişimi)
  List<String> interceptApps = ['com.instagram.android', 'com.zhiliaoapp.musically', 'com.google.android.youtube'];

  Map<String, Object> toJson() => {
        'theme': theme.name, 'pageMode': pageMode.name, 'autoNight': autoNight, 'fontSize': fontSize,
        'justify': justify, 'dailyGoalMin': dailyGoalMin, 'reminderOn': reminderOn,
        'reminderMinutes': reminderMinutes, 'interceptOn': interceptOn, 'interceptApps': interceptApps,
        'keepScreenOn': keepScreenOn,
      };
  void load(Map<String, dynamic> j) {
    theme = AppThemeId.values.asNameMap()[j['theme']] ?? theme;
    pageMode = PageMode.values.asNameMap()[j['pageMode']] ?? pageMode;
    autoNight = (j['autoNight'] as bool?) ?? autoNight;
    fontSize = ((j['fontSize'] as num?) ?? fontSize).toDouble();
    justify = (j['justify'] as bool?) ?? justify;
    dailyGoalMin = (j['dailyGoalMin'] as int?) ?? dailyGoalMin;
    reminderOn = (j['reminderOn'] as bool?) ?? reminderOn;
    reminderMinutes = (j['reminderMinutes'] as int?) ?? reminderMinutes;
    interceptOn = (j['interceptOn'] as bool?) ?? interceptOn;
    interceptApps = ((j['interceptApps'] as List?) ?? interceptApps).cast<String>();
    keepScreenOn = (j['keepScreenOn'] as bool?) ?? keepScreenOn;
  }
}

class LibraryStore extends ChangeNotifier {
  late Directory _root;
  final List<Book> books = [];
  final List<ReadingSession> sessions = [];
  final Settings settings = Settings();
  /// Dürtü kesme kayıtları: [epoch ms, 1 = kitabı seçti / 0 = uygulamaya geçti]
  final List<List<int>> interceptLog = [];
  final List<Highlight> highlights = [];
  /// Her değişiklikten sonra çağrılır (ana ekran widget'ını güncellemek için).
  void Function(LibraryStore)? onChanged;
  final Map<String, BookContent> _contentCache = {};

  AppPalette get palette => AppPalette.of(settings.theme);

  /// Şu an geçerli okuma sayfası (otomatik gece açıksa saate göre).
  PageMode effectivePageMode([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (settings.autoNight && (h >= 20 || h < 7)) return PageMode.gece;
    return settings.pageMode;
  }

  Future<void> load() async {
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}/pagera');
    await Directory('${_root.path}/books').create(recursive: true);
    final f = File('${_root.path}/state.json');
    if (await f.exists()) {
      try {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        books.addAll((j['books'] as List).map((b) => Book.fromJson(b as Map<String, dynamic>)));
        sessions.addAll((j['sessions'] as List).map((s) => ReadingSession.fromJson(s as Map<String, dynamic>)));
        settings.load((j['settings'] as Map<String, dynamic>?) ?? {});
        interceptLog.addAll(((j['intercepts'] as List?) ?? []).map((e) => (e as List).cast<int>()));
        highlights.addAll(((j['highlights'] as List?) ?? []).map((h) => Highlight.fromJson(h as Map<String, dynamic>)));
      } catch (_) {
        // Bozuk dosya: yedeğini al, temiz başla.
        await f.copy('${f.path}.bozuk');
      }
    }
  }

  // Kayıtlar sıraya girer: aynı anda iki yazma aynı .tmp dosyasında çakışmasın.
  Future<void>? _saving;
  bool _dirty = false;

  void _save() {
    _dirty = true;
    _saving ??= _flush();
  }

  Future<void> _flush() async {
    try {
      while (_dirty) {
        _dirty = false;
        await _writeState();
      }
    } finally {
      _saving = null;
    }
  }

  Map<String, Object> _stateJson() => {
        'v': 1,
        'books': books.map((b) => b.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'settings': settings.toJson(),
        'intercepts': interceptLog,
        'highlights': highlights.map((h) => h.toJson()).toList(),
      };

  Future<void> _writeState() async {
    final f = File('${_root.path}/state.json');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(_stateJson()));
    await tmp.rename(f.path);
  }

  void changed() {
    notifyListeners();
    _save();
    onChanged?.call(this);
  }

  // ---- Yedek ----

  /// Tüm durum + kitap içerikleri tek nesnede.
  Future<Map<String, Object>> exportAll() async {
    final contents = <String, Object>{};
    for (final b in books) {
      final f = File('${_root.path}/books/${b.id}.json');
      if (await f.exists()) contents[b.id] = jsonDecode(await f.readAsString()) as Object;
    }
    return {'pagera_backup': 1, 'at': DateTime.now().millisecondsSinceEpoch, 'state': _stateJson(), 'books': contents};
  }

  /// Yedekten geri yükle: mevcut her şeyin yerine geçer.
  Future<void> restoreAll(Map<String, dynamic> backup) async {
    if (backup['pagera_backup'] != 1) throw const FormatException('Bu bir Pagera yedeği değil.');
    final state = backup['state'] as Map<String, dynamic>;
    final contents = backup['books'] as Map<String, dynamic>;
    for (final e in contents.entries) {
      await File('${_root.path}/books/${e.key}.json').writeAsString(jsonEncode(e.value));
    }
    books
      ..clear()
      ..addAll((state['books'] as List).map((b) => Book.fromJson(b as Map<String, dynamic>)));
    sessions
      ..clear()
      ..addAll((state['sessions'] as List).map((s) => ReadingSession.fromJson(s as Map<String, dynamic>)));
    interceptLog
      ..clear()
      ..addAll(((state['intercepts'] as List?) ?? []).map((e) => (e as List).cast<int>()));
    highlights
      ..clear()
      ..addAll(((state['highlights'] as List?) ?? []).map((h) => Highlight.fromJson(h as Map<String, dynamic>)));
    settings.load((state['settings'] as Map<String, dynamic>?) ?? {});
    _contentCache.clear();
    changed();
  }

  // ---- Altı çizililer ----

  List<Highlight> highlightsFor(String bookId) =>
      highlights.where((h) => h.bookId == bookId).toList()..sort((a, b) => a.block != b.block ? a.block - b.block : a.start - b.start);

  void addHighlight(Highlight h) {
    highlights.add(h);
    changed();
  }

  void removeHighlight(Highlight h) {
    highlights.remove(h);
    changed();
  }

  Book? byId(String id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<Book> addBook(String title, String author, BookContent content) async {
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await File('${_root.path}/books/$id.json').writeAsString(jsonEncode(content.toJson()));
    _contentCache[id] = content;
    final b = Book(id: id, title: title, author: author, totalChars: content.totalChars, addedAt: DateTime.now().millisecondsSinceEpoch);
    books.add(b);
    changed();
    return b;
  }

  Future<void> deleteBook(Book b) async {
    books.remove(b);
    highlights.removeWhere((h) => h.bookId == b.id);
    _contentCache.remove(b.id);
    final f = File('${_root.path}/books/${b.id}.json');
    if (await f.exists()) await f.delete();
    changed();
  }

  Future<BookContent> content(Book b) async {
    final c = _contentCache[b.id];
    if (c != null) return c;
    final j = jsonDecode(await File('${_root.path}/books/${b.id}.json').readAsString()) as Map<String, dynamic>;
    return _contentCache[b.id] = BookContent.fromJson(j);
  }

  void savePosition(Book b, int pos) {
    b.position = pos;
    b.lastReadAt = DateTime.now().millisecondsSinceEpoch;
    if (b.totalChars > 0 && pos >= b.totalChars - 400) b.finished = true;
    changed();
  }

  void addSession(ReadingSession s) {
    if (s.seconds < 15) return;
    sessions.add(s);
    changed();
  }

  // ---- İstatistikler ----

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Günlere göre okunan saniye.
  Map<DateTime, int> secondsByDay() {
    final m = <DateTime, int>{};
    for (final s in sessions) {
      final d = _day(DateTime.fromMillisecondsSinceEpoch(s.start));
      m[d] = (m[d] ?? 0) + s.seconds;
    }
    return m;
  }

  int todaySeconds() => secondsByDay()[_day(DateTime.now())] ?? 0;

  /// Kesintisiz seri: bugün (ya da henüz okunmadıysa dün) geriye doğru en az 1 dk okunan günler.
  int streak() {
    final m = secondsByDay();
    var d = _day(DateTime.now());
    if ((m[d] ?? 0) < 60) d = _day(d.subtract(const Duration(hours: 12)));
    var n = 0;
    while ((m[d] ?? 0) >= 60) {
      n++;
      d = _day(d.subtract(const Duration(hours: 12)));
    }
    return n;
  }

  int bestStreak() {
    final days = secondsByDay().entries.where((e) => e.value >= 60).map((e) => e.key).toList()..sort();
    var best = 0, cur = 0;
    DateTime? prev;
    for (final d in days) {
      cur = (prev != null && d.difference(prev).inHours <= 25) ? cur + 1 : 1;
      best = math.max(best, cur);
      prev = d;
    }
    return best;
  }

  /// Okuma hızı (karakter/dakika); veri azsa varsayılan.
  double charsPerMinute() {
    var secs = 0, chars = 0;
    for (final s in sessions) {
      if (s.chars > 0) {
        secs += s.seconds;
        chars += s.chars;
      }
    }
    if (secs < 600) return 1000;
    return (chars / (secs / 60)).clamp(300, 4000).toDouble();
  }

  int sessionsFor(Book b) => sessions.where((s) => s.bookId == b.id).length;
  int secondsFor(Book b) => sessions.where((s) => s.bookId == b.id).fold(0, (a, s) => a + s.seconds);

  Book? get currentBook {
    final started = books.where((b) => b.started && !b.finished).toList()
      ..sort((a, b) => (b.lastReadAt ?? 0).compareTo(a.lastReadAt ?? 0));
    return started.isEmpty ? null : started.first;
  }
}

/// Ağaçta mağazaya erişim.
class AppScope extends InheritedNotifier<LibraryStore> {
  const AppScope({super.key, required LibraryStore store, required super.child}) : super(notifier: store);
  static LibraryStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static LibraryStore read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
