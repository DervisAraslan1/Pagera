// Yedekle / geri yükle: tüm kitaplar, okuma konumları, geçmiş, notlar ve ayarlar tek .pagera dosyasında (gzip'li JSON).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import '../data/library_store.dart';

class Backup {
  /// Kullanıcının seçtiği yere kaydeder. Kaydedildiyse true.
  static Future<bool> export(LibraryStore store) async {
    final data = await store.exportAll();
    final bytes = GZipEncoder().encodeBytes(utf8.encode(jsonEncode(data)));
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final uri = await FilePicker.saveFile(
      fileName: 'pagera-yedek-${d.year}-${two(d.month)}-${two(d.day)}.pagera',
      bytes: Uint8List.fromList(bytes),
      dialogTitle: 'Yedeği kaydet',
    );
    return uri != null;
  }

  /// Seçilen yedekten geri yükler (mevcut verinin yerine geçer). Yüklendiyse true.
  static Future<bool> restore(LibraryStore store) async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Yedek dosyasını seç');
    if (files.isEmpty || files.first.path == null) return false;
    final raw = await File(files.first.path!).readAsBytes();
    List<int> jsonBytes;
    try {
      jsonBytes = GZipDecoder().decodeBytes(raw);
    } catch (_) {
      jsonBytes = raw; // sıkıştırılmamış JSON da kabul
    }
    final map = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
    await store.restoreAll(map);
    return true;
  }
}
