// Dürtü kesme: seçili uygulama (Instagram vb.) açılınca Pagera'yı "Reels yerine" ekranıyla öne getirir.
// Android tarafı: MainActivity.kt (MethodChannel) + InterceptService.kt (kullanım istatistiği izleyen ön plan servisi).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_store.dart';
import '../theme/palettes.dart';

class Intercept {
  static const _ch = MethodChannel('pagera/intercept');
  static void Function(String pkg)? onIntercept;

  static void listen() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'intercepted' && call.arguments is String) onIntercept?.call(call.arguments as String);
    });
  }

  static Future<bool> hasUsageAccess() async => await _ch.invokeMethod<bool>('hasUsageAccess') ?? false;
  static Future<bool> hasOverlay() async => await _ch.invokeMethod<bool>('hasOverlay') ?? false;
  static Future<void> openUsageSettings() => _ch.invokeMethod('openUsageSettings');
  static Future<void> openOverlaySettings() => _ch.invokeMethod('openOverlaySettings');
  static Future<void> start(List<String> apps) => _ch.invokeMethod('start', apps);
  static Future<void> stop() => _ch.invokeMethod('stop');
  static Future<String?> consumePending() => _ch.invokeMethod<String>('consumePending');
  static Future<void> allowFor(String pkg, int minutes) => _ch.invokeMethod('allowFor', {'pkg': pkg, 'minutes': minutes});
  static Future<void> openApp(String pkg) => _ch.invokeMethod('openApp', pkg);

  static const knownApps = {
    'com.instagram.android': 'Instagram',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.google.android.youtube': 'YouTube',
    'com.twitter.android': 'X',
    'com.facebook.katana': 'Facebook',
    'com.reddit.frontpage': 'Reddit',
    'com.snapchat.android': 'Snapchat',
  };
  static String nameOf(String pkg) => knownApps[pkg] ?? pkg;

  /// Ayar açıksa ve izinler tamamsa servisi çalıştır.
  static Future<void> sync(Settings s) async {
    try {
      if (s.interceptOn && await hasUsageAccess() && await hasOverlay()) {
        await start(s.interceptApps);
      } else {
        await stop();
      }
    } on PlatformException {
      // Platform desteklemiyor.
    } on MissingPluginException {
      // Test/masaüstü.
    }
  }
}

class InterceptSettings extends StatefulWidget {
  const InterceptSettings({super.key});
  @override
  State<InterceptSettings> createState() => _InterceptSettingsState();
}

class _InterceptSettingsState extends State<InterceptSettings> with WidgetsBindingObserver {
  bool _usage = false, _overlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final u = await Intercept.hasUsageAccess();
      final o = await Intercept.hasOverlay();
      if (!mounted) return;
      setState(() {
        _usage = u;
        _overlay = o;
      });
      await Intercept.sync(AppScope.read(context).settings);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final p = store.palette;
    final ready = _usage && _overlay;

    Widget permRow(String title, String sub, bool ok, VoidCallback open) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, color: ok ? p.accent : p.muted),
          title: Text(title, style: Fonts.ui(size: 15, color: p.text)),
          subtitle: Text(sub, style: Fonts.ui(size: 12, color: p.muted)),
          trailing: ok ? null : TextButton(onPressed: open, child: const Text('İzin ver')),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Seçtiğin uygulamayı açtığında önce Pagera çıkar: “Kaydırmak yerine 5 sayfa?”',
          style: Fonts.ui(size: 13, color: p.muted, height: 1.5)),
      const SizedBox(height: 6),
      permRow('Kullanım erişimi', 'Hangi uygulamanın açıldığını görmek için', _usage, Intercept.openUsageSettings),
      permRow('Diğer uygulamaların üzerinde göster', 'Ara ekranı öne getirebilmek için', _overlay, Intercept.openOverlaySettings),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Reels yerine kitap', style: Fonts.ui(size: 15, color: p.text, weight: FontWeight.w500)),
        subtitle: Text(ready ? 'Açıkken bildirim çubuğunda küçük bir simge durur' : 'Önce iki izni ver',
            style: Fonts.ui(size: 12, color: p.muted)),
        value: s.interceptOn && ready,
        onChanged: ready
            ? (v) async {
                s.interceptOn = v;
                store.changed();
                await Intercept.sync(s);
              }
            : null,
      ),
      const SizedBox(height: 4),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in Intercept.knownApps.entries)
          FilterChip(
            label: Text(e.value),
            selected: s.interceptApps.contains(e.key),
            showCheckmark: false,
            selectedColor: p.accent,
            backgroundColor: p.text.withValues(alpha: 0.06),
            side: BorderSide(color: p.border),
            labelStyle: Fonts.ui(color: s.interceptApps.contains(e.key) ? p.onAccent : p.text, weight: FontWeight.w500),
            onSelected: (v) async {
              v ? s.interceptApps.add(e.key) : s.interceptApps.remove(e.key);
              store.changed();
              await Intercept.sync(s);
            },
          ),
      ]),
    ]);
  }
}
