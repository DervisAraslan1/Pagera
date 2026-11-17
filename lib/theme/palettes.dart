// Uygulama temaları (3) ve okuma sayfası renkleri (3). Tasarım kanvasındaki değerler.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeId { gece, mese, lacivert }

enum PageMode { kagit, sepya, gece }

class AppPalette {
  final AppThemeId id;
  final String name, tagline;
  final bool dark;
  final List<Color> bg; // üstten alta zemin
  final Color glow; // lamba/ışık parlaması
  final Color text, muted, faint, accent, onAccent, surface, border, nav;
  final Color plankTop, plankBottom;
  final List<Color> spines;
  final Color spineInk, spineInkLight, spineBand;

  const AppPalette({
    required this.id,
    required this.name,
    required this.tagline,
    required this.dark,
    required this.bg,
    required this.glow,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.surface,
    required this.border,
    required this.nav,
    required this.plankTop,
    required this.plankBottom,
    required this.spines,
    required this.spineInk,
    required this.spineInkLight,
    required this.spineBand,
  });

  static const gece = AppPalette(
    id: AppThemeId.gece,
    name: 'Gece Kütüphanesi',
    tagline: 'Koyu ceviz raflar, lamba ışığı',
    dark: true,
    bg: [Color(0xFF3A2614), Color(0xFF22170F), Color(0xFF120C08)],
    glow: Color(0x885B3A1E),
    text: Color(0xFFEFE4D0),
    muted: Color(0xFFB8A184),
    faint: Color(0xFF8F7C64),
    accent: Color(0xFFE8A75D),
    onAccent: Color(0xFF22150A),
    surface: Color(0xF022170F),
    border: Color(0x1FEFE4D0),
    nav: Color(0xFF0F0A07),
    plankTop: Color(0xFF7A4F2C),
    plankBottom: Color(0xFF4A2E18),
    spines: [
      Color(0xFF7A2E2A), Color(0xFF23344F), Color(0xFFD9C9A8), Color(0xFF2F4A3A),
      Color(0xFF4B2D45), Color(0xFFB88A2E), Color(0xFF24525A), Color(0xFF2B2B2B),
      Color(0xFF5A2320), Color(0xFF3C4F2A), Color(0xFF8A5A2B), Color(0xFF6B2B3A),
    ],
    spineInk: Color(0xFFECD39A),
    spineInkLight: Color(0xFF3A2A1C),
    spineBand: Color(0x8CE8C88C),
  );

  static const mese = AppPalette(
    id: AppThemeId.mese,
    name: 'Meşe Kitapçı',
    tagline: 'Gün ışığı, açık meşe, keten duvar',
    dark: false,
    bg: [Color(0xFFF4EDE1), Color(0xFFEDE3D3), Color(0xFFE6D9C4)],
    glow: Color(0xCCFFFAEB),
    text: Color(0xFF2B2118),
    muted: Color(0xFF6E5A45),
    faint: Color(0xFF7A6650),
    accent: Color(0xFF2F5D46),
    onAccent: Color(0xFFF6EFE3),
    surface: Color(0xFFFBF7F0),
    border: Color(0x1A2B2118),
    nav: Color(0xFFF7F1E7),
    plankTop: Color(0xFFD4A874),
    plankBottom: Color(0xFFA87A48),
    spines: [
      Color(0xFF7D3B34), Color(0xFF2A3B55), Color(0xFFE8C77A), Color(0xFF2F5D46),
      Color(0xFFC46A43), Color(0xFF6F7F63), Color(0xFFEFE3C8), Color(0xFF3A3532),
      Color(0xFFF1DFA8), Color(0xFF4F6B7A), Color(0xFF8C5A3C),
    ],
    spineInk: Color(0xFFFBF1DC),
    spineInkLight: Color(0xFF3A2A1C),
    spineBand: Color(0x80FFF0D2),
  );

  static const lacivert = AppPalette(
    id: AppThemeId.lacivert,
    name: 'Lacivert Salon',
    tagline: 'Lacivert duvar, beyaz raf, pirinç',
    dark: true,
    bg: [Color(0xFF17263D), Color(0xFF111D30), Color(0xFF0B1320)],
    glow: Color(0x33D4B06A),
    text: Color(0xFFE8ECF2),
    muted: Color(0xFF9AA7BA),
    faint: Color(0xFF8593A8),
    accent: Color(0xFFD4B06A),
    onAccent: Color(0xFF14203A),
    surface: Color(0xFF1B2B45),
    border: Color(0x1FE8ECF2),
    nav: Color(0xFF08101B),
    plankTop: Color(0xFFF1EDE5),
    plankBottom: Color(0xFFCFC8BA),
    spines: [
      Color(0xFFB23A48), Color(0xFFE9E4DA), Color(0xFF1F6F6B), Color(0xFFC9A45C),
      Color(0xFF5B4A8A), Color(0xFFB95A2A), Color(0xFF2C3E63), Color(0xFF1C1F26),
    ],
    spineInk: Color(0xFFF4EAD6),
    spineInkLight: Color(0xFF1C2A40),
    spineBand: Color(0xB3D4B06A),
  );

  static const all = [gece, mese, lacivert];
  static AppPalette of(AppThemeId id) => all.firstWhere((p) => p.id == id);

  Color inkFor(Color spine) => spine.computeLuminance() > 0.4 ? spineInkLight : spineInk;
}

class PagePalette {
  final PageMode mode;
  final String name;
  final Color bg, text, muted, accent, highlight, chrome;
  const PagePalette(this.mode, this.name, this.bg, this.text, this.muted, this.accent, this.highlight, this.chrome);

  static const kagit = PagePalette(PageMode.kagit, 'Kâğıt', Color(0xFFF3EBDD), Color(0xFF2A211B),
      Color(0xFF6E5C4A), Color(0xFF7A2E2A), Color(0x73E8A75D), Color(0xFFE9DFCD));
  static const sepya = PagePalette(PageMode.sepya, 'Sepya', Color(0xFFE6D2AE), Color(0xFF3B2A17),
      Color(0xFF6F5A3E), Color(0xFF8A4B1C), Color(0x66C47A30), Color(0xFFDBC59D));
  static const gece = PagePalette(PageMode.gece, 'Gece', Color(0xFF000000), Color(0xFFB9AE9F),
      Color(0xFF8A7F72), Color(0xFFD8A065), Color(0x47D8A065), Color(0xFF141210));

  static const all = [kagit, sepya, gece];
  static PagePalette of(PageMode m) => all.firstWhere((p) => p.mode == m);
}

class Fonts {
  static TextStyle display({double size = 28, Color? color, FontWeight weight = FontWeight.w400, FontStyle? style, double? height}) =>
      GoogleFonts.fraunces(fontSize: size, color: color, fontWeight: weight, fontStyle: style, height: height);
  static TextStyle reading({double size = 18, Color? color, double height = 1.72, FontStyle? style}) =>
      GoogleFonts.literata(fontSize: size, color: color, height: height, fontStyle: style);
  static TextStyle ui({double size = 14, Color? color, FontWeight weight = FontWeight.w400, double? letterSpacing, double? height}) =>
      GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight, letterSpacing: letterSpacing, height: height);
  static TextStyle label(Color color) => ui(size: 12, color: color, letterSpacing: 1.6, weight: FontWeight.w500);
}

ThemeData buildTheme(AppPalette p) {
  final scheme = ColorScheme(
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: const Color(0xFFC0392B),
    onError: Colors.white,
    surface: p.dark ? p.bg[1] : p.surface,
    onSurface: p.text,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: scheme.brightness,
    fontFamily: GoogleFonts.inter().fontFamily,
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg.last,
    dividerColor: p.border,
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.dark ? p.nav : p.surface, showDragHandle: true),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.dark ? p.bg[1] : p.surface,
      contentTextStyle: Fonts.ui(color: p.text),
      behavior: SnackBarBehavior.floating,
    ),
    sliderTheme: SliderThemeData(activeTrackColor: p.accent, thumbColor: p.accent, inactiveTrackColor: p.border),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : p.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.border),
    ),
  );
}
