// Ayarlar: uygulama teması, okuma sayfası, hedef, hatırlatıcı, dürtü kesme.
import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../services/backup.dart';
import '../services/intercept.dart';
import '../services/reminders.dart';
import '../theme/palettes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final p = store.palette;

    Widget section(String t) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 12),
          child: Text(t.toUpperCase(), style: Fonts.label(p.muted)),
        );

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 26, 20, 30), children: [
        Text('Görünüm ve ayarlar', style: Fonts.display(size: 28, color: p.text)),
        section('Uygulama teması'),
        for (final t in AppPalette.all) ...[
          _ThemeCard(theme: t, selected: s.theme == t.id, onTap: () {
            s.theme = t.id;
            store.changed();
          }),
          const SizedBox(height: 12),
        ],
        section('Okuma sayfası'),
        Row(children: [
          for (final pg in PagePalette.all) ...[
            Expanded(
              child: Semantics(
                button: true,
                selected: s.pageMode == pg.mode,
                label: '${pg.name} sayfa',
                child: GestureDetector(
                  onTap: () {
                    s.pageMode = pg.mode;
                    store.changed();
                  },
                  child: Container(
                    height: 88,
                    decoration: BoxDecoration(
                      color: pg.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: s.pageMode == pg.mode ? p.accent : p.border, width: s.pageMode == pg.mode ? 2 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Aa', style: Fonts.display(size: 22, color: pg.text)),
                      Text(pg.name, style: Fonts.ui(size: 13, weight: FontWeight.w500, color: pg.text)),
                    ]),
                  ),
                ),
              ),
            ),
            if (pg != PagePalette.all.last) const SizedBox(width: 10),
          ],
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Akşam olunca gece sayfası', style: Fonts.ui(size: 15, color: p.text)),
          subtitle: Text('20:00 – 07:00 arası siyah sayfa', style: Fonts.ui(size: 12, color: p.muted)),
          value: s.autoNight,
          onChanged: (v) {
            s.autoNight = v;
            store.changed();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Okurken ekranı açık tut', style: Fonts.ui(size: 15, color: p.text)),
          subtitle: Text(
            s.keepScreenOn
                ? 'Kitap açık kaldıkça ekran hiç kararmaz (daha çok pil)'
                : 'Son dokunuştan 5 dk sonra telefonun normal ekran süresi işler',
            style: Fonts.ui(size: 12, color: p.muted),
          ),
          value: s.keepScreenOn,
          onChanged: (v) {
            s.keepScreenOn = v;
            store.changed();
          },
        ),
        section('Günlük hedef'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in [10, 15, 20, 30, 45, 60])
            ChoiceChip(
              label: Text('$m dk'),
              selected: s.dailyGoalMin == m,
              showCheckmark: false,
              selectedColor: p.accent,
              backgroundColor: p.text.withValues(alpha: 0.06),
              side: BorderSide(color: p.border),
              labelStyle: Fonts.ui(color: s.dailyGoalMin == m ? p.onAccent : p.text, weight: FontWeight.w500),
              onSelected: (_) {
                s.dailyGoalMin = m;
                store.changed();
              },
            ),
        ]),
        section('Hatırlatıcı'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Her gün okuma hatırlatması', style: Fonts.ui(size: 15, color: p.text)),
          subtitle: Text(_hm(s.reminderMinutes), style: Fonts.ui(size: 12, color: p.muted)),
          value: s.reminderOn,
          onChanged: (v) async {
            if (v) await Reminders.requestPermission();
            s.reminderOn = v;
            store.changed();
            await Reminders.schedule(v ? s.reminderMinutes : null, bookTitle: store.currentBook?.title);
          },
        ),
        if (s.reminderOn)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule, color: p.muted),
            title: Text('Saati değiştir', style: Fonts.ui(size: 15, color: p.text)),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: s.reminderMinutes ~/ 60, minute: s.reminderMinutes % 60),
              );
              if (t == null) return;
              s.reminderMinutes = t.hour * 60 + t.minute;
              store.changed();
              await Reminders.schedule(s.reminderMinutes, bookTitle: store.currentBook?.title);
            },
          ),
        section('Reels yerine kitap'),
        const InterceptSettings(),
        section('Yedek'),
        Text('Kitaplar, okuma konumları, geçmiş, notlar ve ayarlar tek dosyada. Telefon değiştirirken ya da uygulamayı silmeden önce al.',
            style: Fonts.ui(size: 13, color: p.muted, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: p.text,
                minimumSize: const Size(0, 50),
                side: BorderSide(color: p.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final ok = await Backup.export(store);
                  if (ok) messenger.showSnackBar(const SnackBar(content: Text('Yedek kaydedildi')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Yedek alınamadı: $e')));
                }
              },
              icon: const Icon(Icons.save_alt, size: 19),
              label: const Text('Yedek al'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: p.text,
                minimumSize: const Size(0, 50),
                side: BorderSide(color: p.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final sure = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Yedekten geri yüklensin mi?'),
                    content: const Text('Şu anki raf, geçmiş ve notlar yedektekilerle değiştirilecek.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri yükle')),
                    ],
                  ),
                );
                if (sure != true) return;
                try {
                  final ok = await Backup.restore(store);
                  if (ok) messenger.showSnackBar(const SnackBar(content: Text('Yedek geri yüklendi')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Geri yüklenemedi: $e')));
                }
              },
              icon: const Icon(Icons.restore, size: 19),
              label: const Text('Geri yükle'),
            ),
          ),
        ]),
      ]),
    );
  }

  static String _hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

class _ThemeCard extends StatelessWidget {
  final AppPalette theme;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeCard({required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final t = theme;
    return Semantics(
      button: true,
      selected: selected,
      label: t.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? p.accent.withValues(alpha: 0.10) : p.text.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? p.accent : p.border, width: selected ? 2 : 1),
          ),
          child: Row(children: [
            Container(
              width: 118,
              height: 84,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: t.bg),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 6; i++)
                    Container(
                      width: [9.0, 7.0, 6.0, 9.0, 8.0, 7.0][i],
                      height: [40.0, 32.0, 28.0, 38.0, 34.0, 30.0][i],
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: t.spines[i % t.spines.length],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                ]),
                Container(
                  height: 6,
                  decoration: BoxDecoration(color: t.plankTop, borderRadius: BorderRadius.circular(1)),
                ),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: Fonts.display(size: 18, color: p.text)),
                const SizedBox(height: 3),
                Text(t.tagline, style: Fonts.ui(size: 13, color: p.muted, height: 1.4)),
              ]),
            ),
            if (selected) Icon(Icons.check_circle, color: p.accent),
          ]),
        ),
      ),
    );
  }
}
