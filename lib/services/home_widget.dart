// Ana ekran widget'ına veri gönderir (Android: PageraWidget.kt okur).
import 'dart:async';

import 'package:flutter/services.dart';

import '../data/library_store.dart';

class HomeWidget {
  static const _ch = MethodChannel('pagera/intercept');
  static Timer? _debounce;
  static String _last = '';

  /// Değişiklikleri biriktirip 2 sn sonra tek seferde gönderir (pil dostu).
  static void schedule(LibraryStore store) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => push(store));
  }

  static Future<void> push(LibraryStore store) async {
    final b = store.currentBook;
    final today = store.todaySeconds() ~/ 60;
    final data = {
      'title': b?.title ?? 'Rafın seni bekliyor',
      'progress': b == null ? '' : '%${(b.progress * 100).toStringAsFixed(0)} okundu',
      'streak': '${store.streak()} gün',
      'goal': '$today / ${store.settings.dailyGoalMin} dk',
      'theme': store.settings.theme.name,
    };
    final sig = data.toString();
    if (sig == _last) return;
    _last = sig;
    try {
      await _ch.invokeMethod('updateWidget', data);
    } on MissingPluginException {
      // test / desteklenmeyen platform
    } on PlatformException {
      // widget eklenmemiş olabilir
    }
  }
}
