// Uygulama simgesini üretir (Flutter çizim motoruyla). Çalıştır: flutter test tool/make_icon_test.dart
// Çıktı: android/app/src/main/res altındaki mipmap/drawable PNG'leri.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

enum Layer { legacy, background, foreground, mono, stat }

/// Tasarım 0..1 birim karede (adaptive simgenin 108dp ızgarası). Güvenli alan: merkez 0.5, yarıçap ~0.31.
void paintIcon(Canvas c, double s, Layer layer) {
  c.save();
  c.scale(s);

  final mono = layer == Layer.mono || layer == Layer.stat;

  if (layer == Layer.legacy) {
    c.clipRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 1, 1), const Radius.circular(0.22)));
  }
  if (layer == Layer.legacy || layer == Layer.background) {
    c.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, 1),
            [const Color(0xFF4A3019), const Color(0xFF1C130C), const Color(0xFF110B07)], [0, 0.55, 1]),
    );
    c.drawCircle(
      const Offset(0.5, 0.18),
      0.62,
      Paint()..shader = ui.Gradient.radial(const Offset(0.5, 0.18), 0.62, [const Color(0x66E8A75D), const Color(0x00E8A75D)]),
    );
    if (layer == Layer.background) {
      c.restore();
      return;
    }
  }

  // Ön plan: eski tip simgede biraz büyüt, bildirim simgesinde daha da büyüt.
  final zoom = switch (layer) { Layer.legacy => 1.28, Layer.stat => 1.55, _ => 1.12 };
  c.translate(0.5, 0.5);
  c.scale(zoom);
  c.translate(-0.5, -0.52);

  const base = 0.655;

  // Amber kitabın arkasındaki lamba ışığı.
  if (!mono) {
    c.drawCircle(
      const Offset(0.445, 0.43),
      0.2,
      Paint()..shader = ui.Gradient.radial(const Offset(0.445, 0.43), 0.2, [const Color(0x99E8A75D), const Color(0x00E8A75D)]),
    );
  }

  void spine(double x, double w, double top, int color, int band, {double angle = 0}) {
    c.save();
    if (angle != 0) {
      c.translate(x, base);
      c.rotate(angle);
      c.translate(-x, -base);
    }
    final rect = Rect.fromLTRB(x, top, x + w, base);
    final rr = RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(0.012), topRight: const Radius.circular(0.012));
    if (mono) {
      c.drawRRect(rr, Paint()..color = Colors.white);
    } else {
      c.drawRRect(rr.shift(const Offset(0.004, 0.006)), Paint()..color = const Color(0x55000000));
      c.drawRRect(
        rr,
        Paint()
          ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x + w, 0), [
            Color.lerp(Color(color), Colors.white, 0.12)!,
            Color(color),
            Color.lerp(Color(color), Colors.black, 0.3)!,
          ], [0, 0.35, 1]),
      );
      final bp = Paint()..color = Color(band);
      const bh = 0.011;
      c.drawRect(Rect.fromLTWH(x + w * 0.16, top + 0.045, w * 0.68, bh), bp);
      c.drawRect(Rect.fromLTWH(x + w * 0.16, base - 0.06, w * 0.68, bh), bp);
    }
    c.restore();
  }

  spine(0.305, 0.082, 0.385, 0xFF7A2E2A, 0xCCECD39A);
  spine(0.395, 0.1, 0.3, 0xFFE8A75D, 0xCC5A3A1A);
  spine(0.503, 0.072, 0.405, 0xFF23344F, 0xCCECD39A);
  spine(0.61, 0.07, 0.42, 0xFF2F4A3A, 0xCCECD39A, angle: -0.2);

  // Raf tahtası.
  final plank = RRect.fromRectAndRadius(const Rect.fromLTRB(0.28, base, 0.72, base + 0.034), const Radius.circular(0.008));
  final pp = Paint();
  if (mono) {
    pp.color = Colors.white;
  } else {
    pp.shader = ui.Gradient.linear(const Offset(0, base), const Offset(0, base + 0.034), [const Color(0xFF9A6838), const Color(0xFF4A2E18)]);
  }
  c.drawRRect(plank, pp);
  c.restore();
}

Future<void> render(String path, int px, Layer layer) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
  paintIcon(canvas, px.toDouble(), layer);
  final img = await rec.endRecording().toImage(px, px);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(data!.buffer.asUint8List());
}

void main() {
  testWidgets('simge üret', (tester) async {
    await tester.runAsync(() async {
      const dens = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
      for (final e in dens.entries) {
        final d = e.value;
        await render('$_res/mipmap-${e.key}/ic_launcher.png', (48 * d).round(), Layer.legacy);
        await render('$_res/mipmap-${e.key}/ic_launcher_foreground.png', (108 * d).round(), Layer.foreground);
        await render('$_res/mipmap-${e.key}/ic_launcher_background.png', (108 * d).round(), Layer.background);
        await render('$_res/mipmap-${e.key}/ic_launcher_monochrome.png', (108 * d).round(), Layer.mono);
        await render('$_res/drawable-${e.key}/ic_stat_pagera.png', (24 * d).round(), Layer.stat);
      }
      // Önizleme: 512 px.
      await render('build/icon_preview.png', 512, Layer.legacy);
      await render('build/icon_preview_mono.png', 256, Layer.stat);
    });
  });
}
