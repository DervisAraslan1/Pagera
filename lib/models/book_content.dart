// Ciltlenmiş kitabın içeriği: başlık / paragraf / dize blokları.
enum BlockKind { heading, paragraph, verse }

class Block {
  final BlockKind kind;
  final String text;
  const Block(this.kind, this.text);

  List<Object> toJson() => [kind.index, text];
  static Block fromJson(List<dynamic> j) => Block(BlockKind.values[j[0] as int], j[1] as String);
}

/// Bölüm: içindekiler ve sayfalama birimi. [start] dahil, [end] hariç blok indeksleri.
class Chapter {
  final String title;
  final int start, end;
  const Chapter(this.title, this.start, this.end);
}

class BookContent {
  final List<Block> blocks;
  late final List<Chapter> chapters = _buildChapters();

  /// Her bloğun kitap başından itibaren karakter ofseti (ilerleme hesabı için).
  late final List<int> offsets = _buildOffsets();
  late final int totalChars = blocks.isEmpty ? 0 : offsets.last + blocks.last.text.length;

  BookContent(this.blocks);

  List<int> _buildOffsets() {
    final o = List<int>.filled(blocks.length, 0);
    var acc = 0;
    for (var i = 0; i < blocks.length; i++) {
      o[i] = acc;
      acc += blocks[i].text.length;
    }
    return o;
  }

  List<Chapter> _buildChapters() {
    final res = <Chapter>[];
    var start = 0;
    var title = 'Başlangıç';
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].kind == BlockKind.heading && i > start) {
        res.add(Chapter(title, start, i));
        start = i;
      }
      if (blocks[i].kind == BlockKind.heading) title = blocks[i].text;
    }
    if (start < blocks.length) res.add(Chapter(title, start, blocks.length));
    // Çok uzun bölümleri (başlık bulunamayan kitaplar) sayfalama için böl.
    final out = <Chapter>[];
    for (final c in res) {
      var s = c.start;
      var part = 1;
      while (s < c.end) {
        var e = s;
        var chars = 0;
        while (e < c.end && (chars < 60000 || e == s)) {
          chars += blocks[e].text.length;
          e++;
        }
        out.add(Chapter(part == 1 ? c.title : '${c.title} ($part)', s, e));
        s = e;
        part++;
      }
    }
    return out;
  }

  int chapterIndexOfBlock(int block) {
    for (var i = 0; i < chapters.length; i++) {
      if (block < chapters[i].end) return i;
    }
    return chapters.length - 1;
  }

  Map<String, Object> toJson() => {'v': 1, 'blocks': blocks.map((b) => b.toJson()).toList()};
  static BookContent fromJson(Map<String, dynamic> j) =>
      BookContent((j['blocks'] as List).map((b) => Block.fromJson(b as List)).toList());
}
