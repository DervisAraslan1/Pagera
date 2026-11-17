# Pagera

Reels kaydırmak yerine kitap okumayı alışkanlık haline getiren Android uygulaması.

Açılış ekranı bir kütüphane rafı: kitap sırtları rafta durur, dokununca raftan çekilir ve okunur. PDF'ler doğrudan gösterilmez; içe aktarılırken bir kez temiz metne "ciltlenir", okuma uygulamanın kendi tipografisiyle yapılır.

## Özellikler

- **Ciltleme:** PDF, EPUB ve TXT içe aktarılır. Paragraflar satır konumlarından bulunur; sayfa numaraları, tekrar eden üst/alt bilgiler ve satır sonu tireleri temizlenir. Metni olmayan (taranmış) PDF'lerde cihazda OCR çalışır.
- **Okuyucu:** kendi sayfalama motoru, Kâğıt / Sepya / Gece sayfaları, yazı tipi ve punto ayarı, akşam otomatik gece sayfası.
- **Altı çizili cümleler ve notlar:** paragrafa uzun bas, cümleyi seç, not ekle.
- **Reels yerine:** seçtiğin uygulama (ör. Instagram) açılınca Pagera öne gelir ve kaldığın kitabı önerir. "Yine de devam" 10 dakika serbest bırakır.
- **Odak ve ilerleme:** okuma oturumları, günlük seri, günlük hatırlatma bildirimi.
- **Ana ekran widget'ı:** okunan kitap ve ilerleme.
- **Yedekleme:** tüm kütüphane ve notlar tek `.pagera` dosyasına.
- 3 uygulama teması. İnternet izni yok; her şey telefonda kalır.

## İndir

Son sürüm: [dervisaraslan1.github.io/indirmeler](https://dervisaraslan1.github.io/indirmeler/)

## Derleme

```bash
flutter pub get
flutter analyze
flutter test test
flutter build apk --release --target-platform android-arm64
```

İmza için `android/key.properties` gerekir (repoda yok). Dosya yoksa derleme debug anahtarıyla imzalanır.

## Yapı

| Klasör | İşi |
|---|---|
| `lib/binder/` | PDF satırlarından başlık, paragraf ve dize çıkaran ciltleyici (saf Dart) |
| `lib/reader/` | Sayfalama motoru ve okuyucu |
| `lib/data/` | Kütüphane durumu ve JSON kalıcılığı |
| `lib/screens/` | Kütüphane, kitap, okuyucu, odak, ilerleme, ayarlar |
| `lib/services/` | Bildirimler, Reels yakalama kanalı, yedekleme |
| `android/.../InterceptService.kt` | Ön plandaki uygulamayı izleyen servis |
| `tool/` | PDF ölçüm araçları ve simge üretici |

Yazı tipleri (Fraunces, Literata, Inter) SIL Open Font License ile uygulamaya gömülüdür.
