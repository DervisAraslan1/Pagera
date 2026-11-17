// Kütüphane görselleri: arka plan, kitap sırtı, raf tahtası, kapak, küçük göstergeler.
import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../theme/palettes.dart';

int _hash(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
  }
  return h;
}

/// Kitabın kimliğinden türeyen sabit görünüş (renk, boy, kalınlık).
class SpineLook {
  final Color color;
  final double width, height;
  SpineLook(this.color, this.width, this.height);
  factory SpineLook.of(Book b, AppPalette p) {
    final h = _hash(b.title + b.id);
    final color = p.spines[h % p.spines.length];
    final width = (24 + b.totalChars / 60000).clamp(24.0, 52.0);
    final height = 128.0 + (h >> 4) % 44;
    return SpineLook(color, width, height);
  }
}

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: p.bg),
      ),
      child: Stack(children: [
        Positioned(
          top: -160,
          left: -80,
          right: -80,
          height: 420,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [p.glow, p.glow.withValues(alpha: 0)]),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ]),
    );
  }
}

class BookSpine extends StatelessWidget {
  final Book book;
  final bool highlighted;
  final VoidCallback? onTap, onLongPress;
  const BookSpine({super.key, required this.book, this.highlighted = false, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final look = SpineLook.of(book, p);
    final ink = p.inkFor(look.color);
    final light = look.color.computeLuminance() > 0.4;
    final band = light ? ink.withValues(alpha: 0.4) : p.spineBand;
    return Semantics(
      button: true,
      label: '${book.title}${highlighted ? ', okunuyor' : ''}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, highlighted ? -12 : 0, 0),
          child: Hero(
            tag: 'book-${book.id}',
            child: Container(
              width: look.width,
              height: look.height,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(1)),
                border: highlighted ? Border.all(color: p.accent.withValues(alpha: 0.8)) : null,
                boxShadow: [
                  if (highlighted) BoxShadow(color: p.accent.withValues(alpha: 0.45), blurRadius: 26),
                  const BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
                gradient: LinearGradient(colors: [
                  Color.lerp(look.color, Colors.white, 0.10)!,
                  look.color,
                  look.color,
                  Color.lerp(look.color, Colors.black, 0.28)!,
                ], stops: const [0, 0.12, 0.82, 1]),
              ),
              child: Column(children: [
                const SizedBox(height: 13),
                Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 4), color: band),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Center(
                        child: Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fonts.display(size: look.width > 34 ? 12.5 : 11.5, color: ink).copyWith(letterSpacing: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 4), color: band),
                const SizedBox(height: 13),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class Plank extends StatelessWidget {
  const Plank({super.key});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Container(
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.plankTop, p.plankBottom]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: p.dark ? 0.55 : 0.25), blurRadius: 18, offset: const Offset(0, 10))],
      ),
    );
  }
}

/// Üretilmiş kitap kapağı (kitabın sırt rengiyle).
class BookCover extends StatelessWidget {
  final Book book;
  final double width;
  const BookCover({super.key, required this.book, this.width = 196});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final look = SpineLook.of(book, p);
    final ink = p.inkFor(look.color);
    final h = width * 1.48;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(8)),
        gradient: LinearGradient(colors: [
          Color.lerp(look.color, Colors.black, 0.35)!,
          Color.lerp(look.color, Colors.white, 0.06)!,
          look.color,
        ], stops: const [0, 0.07, 0.3]),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 50, offset: const Offset(0, 28)),
          BoxShadow(color: p.accent.withValues(alpha: 0.15), blurRadius: 80),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(width * 0.14, width * 0.11, width * 0.09, width * 0.11),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: ink.withValues(alpha: 0.6))),
          padding: EdgeInsets.symmetric(horizontal: width * 0.06, vertical: width * 0.12),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              book.author.isEmpty ? ' ' : book.author.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Fonts.ui(size: width * 0.05, color: ink, letterSpacing: 2),
            ),
            Text(
              book.title,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: Fonts.display(size: width * 0.12, color: ink, height: 1.12),
            ),
            CustomPaint(size: Size(width * 0.18, width * 0.1), painter: _Ornament(ink)),
          ]),
        ),
      ),
    );
  }
}

class _Ornament extends CustomPainter {
  final Color c;
  _Ornament(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = c
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final cy = s.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(s.width * 0.3, cy), paint);
    canvas.drawLine(Offset(s.width * 0.7, cy), Offset(s.width, cy), paint);
    final path = Path()
      ..moveTo(s.width / 2, 0)
      ..lineTo(s.width * 0.62, cy)
      ..lineTo(s.width / 2, s.height)
      ..lineTo(s.width * 0.38, cy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_Ornament oldDelegate) => oldDelegate.c != c;
}

class ProgressLine extends StatelessWidget {
  final double value;
  final Color color, track;
  final double height;
  final bool glow;
  const ProgressLine({super.key, required this.value, required this.color, required this.track, this.height = 4, this.glow = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height),
            boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 12)] : null,
          ),
        ),
      ),
    );
  }
}

class StreakChip extends StatelessWidget {
  final int days;
  const StreakChip({super.key, required this.days});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.accent.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.local_fire_department_outlined, size: 17, color: p.accent),
        const SizedBox(width: 6),
        Text('$days gün', style: Fonts.ui(size: 14, weight: FontWeight.w600, color: p.accent)),
      ]),
    );
  }
}

String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes dk';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h sa' : '$h sa $m dk';
}
