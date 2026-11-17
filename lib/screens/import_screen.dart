// Ciltleme ekranı: PDF/TXT'yi okur, metne çevirir, önizletir, rafa koyar.
import 'package:flutter/material.dart';

import '../binder/importer.dart';
import '../data/library_store.dart';
import '../models/book_content.dart';
import '../theme/palettes.dart';
import '../widgets/shelf_widgets.dart';

class ImportScreen extends StatefulWidget {
  final String path;
  const ImportScreen({super.key, required this.path});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  int _done = 0, _total = 1;
  String _stage = 'Hazırlanıyor';
  BookContent? _content;
  String? _error;
  late final TextEditingController _title = TextEditingController(text: Importer.guessTitle(widget.path));
  final _author = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final c = await Importer.importFile(widget.path, (d, t, s) {
        if (mounted) {
          setState(() {
            _done = d;
            _total = t;
            _stage = s;
          });
        }
      });
      if (c.blocks.length < 3) throw Exception('Dosyadan okunabilir metin çıkmadı.');
      if (mounted) setState(() => _content = c);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final store = AppScope.read(context);
    await store.addBook(_title.text.trim().isEmpty ? 'Adsız kitap' : _title.text.trim(), _author.text.trim(), _content!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _error != null
                ? _buildError(p)
                : _content == null
                    ? _buildProgress(p)
                    : _buildPreview(p, _content!),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(AppPalette p) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.auto_stories_outlined, size: 56, color: p.accent),
        const SizedBox(height: 22),
        Text('Kitap ciltleniyor', style: Fonts.display(size: 26, color: p.text)),
        const SizedBox(height: 8),
        Text('$_stage · $_done / $_total', style: Fonts.ui(size: 14, color: p.muted)),
        const SizedBox(height: 22),
        ProgressLine(value: _done / _total, color: p.accent, track: p.text.withValues(alpha: 0.12), glow: p.dark),
        const SizedBox(height: 16),
        Text('Bu bir kez yapılır; sonra kitap anında açılır.', style: Fonts.ui(size: 13, color: p.faint)),
      ]);

  Widget _buildError(AppPalette p) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.report_outlined, size: 52, color: p.muted),
        const SizedBox(height: 18),
        Text('Bu dosya rafa konamadı', style: Fonts.display(size: 24, color: p.text)),
        const SizedBox(height: 10),
        Text(_error!, textAlign: TextAlign.center, style: Fonts.ui(size: 14, color: p.muted, height: 1.5)),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Geri dön')),
      ]);

  Widget _buildPreview(AppPalette p, BookContent c) {
    final page = PagePalette.kagit;
    final heads = c.blocks.where((b) => b.kind == BlockKind.heading).length;
    final paras = c.blocks.where((b) => b.kind == BlockKind.paragraph).toList();
    // Önizleme: ilk uzun paragraf (kitabın kendi girişi değil, ortalarda bir yer olabilir).
    final sample = paras.isEmpty ? '' : paras[(paras.length * 0.05).floor()].text;
    final clipped = sample.length > 420 ? '${sample.substring(0, 420)}…' : sample;
    return ListView(children: [
      const SizedBox(height: 18),
      Text('Kitabın böyle görünecek', style: Fonts.display(size: 26, color: p.text)),
      const SizedBox(height: 6),
      Text('$heads bölüm başlığı · ${paras.length} paragraf · ${formatMinutes((c.totalChars / 1000).round())} okuma',
          style: Fonts.ui(size: 13, color: p.muted)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: page.bg, borderRadius: BorderRadius.circular(16)),
        child: Text(clipped, textAlign: TextAlign.justify, style: Fonts.reading(size: 16, color: page.text)),
      ),
      const SizedBox(height: 22),
      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Kitap adı')),
      const SizedBox(height: 8),
      TextField(controller: _author, decoration: const InputDecoration(labelText: 'Yazar (isteğe bağlı)')),
      const SizedBox(height: 26),
      SizedBox(
        height: 56,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            foregroundColor: p.onAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: _saving ? null : _save,
          child: Text('Rafa koy', style: Fonts.ui(size: 16, weight: FontWeight.w600, color: p.onAccent)),
        ),
      ),
      TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç', style: Fonts.ui(color: p.muted))),
      const SizedBox(height: 20),
    ]);
  }
}
