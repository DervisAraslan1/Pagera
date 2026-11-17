// İlerleme: seri, aylık okuma takvimi, bitirilen kitap yığını.
import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../theme/palettes.dart';
import '../widgets/shelf_widgets.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  static const _months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = store.palette;
    final now = DateTime.now();
    final byDay = store.secondsByDay();
    final monthSecs = byDay.entries.where((e) => e.key.year == now.year && e.key.month == now.month).fold(0, (a, e) => a + e.value);
    final readDays = byDay.entries.where((e) => e.key.year == now.year && e.key.month == now.month && e.value >= 60).length;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday; // 1 = Pazartesi
    final goalSecs = store.settings.dailyGoalMin * 60;
    final finished = store.books.where((b) => b.finished).toList();
    final totalSecs = store.sessions.fold(0, (a, s) => a + s.seconds);

    Color cellColor(int secs) {
      if (secs < 60) return p.text.withValues(alpha: 0.07);
      final r = secs / goalSecs;
      if (r < 0.5) return Color.lerp(p.bg.first, p.accent, 0.35)!;
      if (r < 1) return Color.lerp(p.bg.first, p.accent, 0.65)!;
      return p.accent;
    }

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(22, 26, 22, 24), children: [
        Text(_months[now.month - 1].toUpperCase(), style: Fonts.label(p.muted)),
        const SizedBox(height: 4),
        Text('İlerleme', style: Fonts.display(size: 32, color: p.text)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: _Tile(
              value: '${store.streak()} gün',
              label: 'kesintisiz seri · rekor ${store.bestStreak()}',
              highlight: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _Tile(value: formatMinutes(monthSecs ~/ 60), label: 'bu ay okuma')),
        ]),
        const SizedBox(height: 28),
        Row(children: [
          Text('Okuma günlerin', style: Fonts.display(size: 17, color: p.text)),
          const Spacer(),
          Text('$readDays / $daysInMonth gün', style: Fonts.ui(size: 12, color: p.muted)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (final d in ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'])
            Expanded(child: Center(child: Text(d, style: Fonts.ui(size: 11, color: p.faint)))),
        ]),
        const SizedBox(height: 6),
        Semantics(
          label: '${_months[now.month - 1]} okuma takvimi: $readDays gün okundu',
          child: GridView.count(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 1; i < firstWeekday; i++) const SizedBox(),
              for (var d = 1; d <= daysInMonth; d++)
                Builder(builder: (_) {
                  final date = DateTime(now.year, now.month, d);
                  final secs = byDay[date] ?? 0;
                  final isToday = d == now.day;
                  return Container(
                    decoration: BoxDecoration(
                      color: date.isAfter(now) ? p.text.withValues(alpha: 0.03) : cellColor(secs),
                      borderRadius: BorderRadius.circular(6),
                      border: isToday ? Border.all(color: p.text, width: 1.5) : null,
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('az', style: Fonts.ui(size: 11, color: p.faint)),
          for (final s in [goalSecs ~/ 4, goalSecs * 3 ~/ 4, goalSecs])
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: cellColor(s), borderRadius: BorderRadius.circular(3)),
            ),
          Text('hedef', style: Fonts.ui(size: 11, color: p.faint)),
        ]),
        const SizedBox(height: 30),
        Text('Bitirdiklerin', style: Fonts.display(size: 17, color: p.text)),
        const SizedBox(height: 12),
        if (finished.isEmpty)
          Text('İlk kitabını bitirdiğinde burada yığılmaya başlayacak.', style: Fonts.ui(size: 13, color: p.muted))
        else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < finished.length; i++)
              Builder(builder: (_) {
                final b = finished[i];
                final look = SpineLook.of(b, p);
                return Container(
                  height: 16 + look.width * 0.3,
                  width: (190 + look.height % 90).toDouble(),
                  margin: EdgeInsets.only(left: (i * 7) % 18.0, bottom: 4),
                  padding: const EdgeInsets.only(left: 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(color: look.color, borderRadius: BorderRadius.circular(2)),
                  child: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Fonts.display(size: 12, color: p.inkFor(look.color))),
                );
              }),
            Container(
              height: 10,
              width: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.plankTop, p.plankBottom]),
              ),
            ),
          ]),
        const SizedBox(height: 12),
        Text('${finished.length} kitap · toplam ${formatMinutes(totalSecs ~/ 60)} okuma', style: Fonts.ui(size: 13, color: p.muted)),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final String value, label;
  final bool highlight;
  const _Tile({required this.value, required this.label, this.highlight = false});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? p.accent.withValues(alpha: 0.1) : p.text.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: highlight ? Border.all(color: p.accent.withValues(alpha: 0.25)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FittedBox(child: Text(value, style: Fonts.display(size: 28, color: highlight ? p.accent : p.text))),
        const SizedBox(height: 2),
        Text(label, style: Fonts.ui(size: 12, color: p.muted)),
      ]),
    );
  }
}
