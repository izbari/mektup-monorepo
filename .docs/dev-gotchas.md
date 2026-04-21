# Teknik Gotcha'lar ve Bilinen Tuzaklar — Mektup

## Nasil kullanilir

Gelistirme sirasinda kesfedilen, diger gelistiricilerin bilmesi gereken teknik tuzaklar, surprizler ve dikkat edilmesi gereken noktalar buraya kaydedilir.

Agent'lar bu dosyayi su durumlarda gunceller:
- Beklenmedik bir davranis kesfedildiginde
- Bir hatanin kok nedeni bulundugunda
- Belirli bir kutuphane, framework veya altyapiyla ilgili kritik bilgi ogrenildiginde
- "Bunu daha once bilseydim saatlerimi kurtarirdim" niteliginde bilgiye ulasildiginda

## Format

```
### [Kisa baslik]
- **Tarih:** YYYY-MM-DD
- **Konu:** Mobile / Web / Backend / Core / Crypto / CI / Infra
- **Detay:** Ne oluyor ve neden?
- **Cozum/Onlem:** Nasil ele alinmali?
- **Architecture referans:** (varsa section X.Y)
```

---

## Mimari dokumandan turetilen baslangic kayitlari

### WatermelonDB Expo config plugin ve Dev Client
- **Tarih:** 2026-04-21
- **Konu:** Mobile
- **Detay:** WatermelonDB managed workflow'da calismaz; native JSI binding ister. Expo managed'dan ciktiginda `ios/`, `android/` klasorleri **asla elle edit edilmemeli**.
- **Cozum/Onlem:** Expo Dev Client kullanilir. WatermelonDB config plugin `app.config.ts` icinde register edilir. Native build her zaman `npx expo prebuild` ile uretilir (continuous native generation). Native degisiklik gerektiginde once config plugin, sonra prebuild.
- **Architecture referans:** section 3.3, 3.2

### WASM SQLite web'de 3-5x yavas
- **Tarih:** 2026-04-21
- **Konu:** Web
- **Detay:** WASM SQLite native SQLite'a gore 3-5 kat yavastir. Naif kullanim UI jank uretir.
- **Cozum/Onlem:** Yazilar batch'lenir, FTS index sadece son 10k mesaj icin (eskiler server search). OPFS quota ~2 GB kap, oldest-first eviction. libsignal+SQLite WASM bundle (~1.2 MB gzipped) first paint sonrasi defer.
- **Architecture referans:** section 16.6

### iOS background task 28 saniye butceli
- **Tarih:** 2026-04-21
- **Konu:** Mobile
- **Detay:** iOS `BGAppRefreshTaskRequest` 30 sn sonra terminate eder. Silent high-priority push app'i uyandirir ama is penceresi ~28 saniye.
- **Cozum/Onlem:** Arka planda bounded is birimi: queue'dan birkac op drain + per-chat cursor pull. AI translation background'da ASLA calismaz — sadece foreground entry'de. Sync ops WAL-mode SQLite ile crash-safe.
- **Architecture referans:** section 11.2, 21.3

### Android WorkManager foreground service grant cogunlukla yok
- **Tarih:** 2026-04-21
- **Konu:** Mobile
- **Detay:** Android foreground service chat app'e cogu kullanici tarafindan grant edilmez. WorkManager periodic job (min 15 dk) yeterli degil.
- **Cozum/Onlem:** FCM high-priority expedited work primary wakeup. Periodic job destek olarak tutulur.

### WebRTC NAT traversal %15-20 fail
- **Tarih:** 2026-04-21
- **Konu:** Mobile/Web (Calls)
- **Detay:** Symmetric-NAT ve carrier-NAT'lar cagrilarin %20-30'unu P2P'den dusurur; captive portal / corporate proxy'ler UDP'yi bloklar.
- **Cozum/Onlem:** TURN her yerde. coturn TLS:5349 + UDP:3478 + TCP:443. Port 443 fallback zorunlu. Credentials HMAC-derived 10 dk TTL.
- **Architecture referans:** section 9.3

### Clock drift wall-clock sort'a guvenilemez
- **Tarih:** 2026-04-21
- **Konu:** Core
- **Detay:** Cihaz saatleri saatlerce yanlis olabilir. Wall-clock sort chat'i yanlis gosterir.
- **Cozum/Onlem:** Siralama SADECE server-assigned `chat_seq`. Wall-clock sadece display, server time'dan 2 dk+ sapma varsa suppress edilir, server time gosterilir.
- **Architecture referans:** section 6.8, 11.5

### UUIDv7 monotonik counter clock-backwards emniyeti
- **Tarih:** 2026-04-21
- **Konu:** Core
- **Detay:** UUIDv7 time-ordered ama saat geri alinirsa (NTP resync) ayni timestamp'ten iki UUID cikabilir.
- **Cozum/Onlem:** UUIDv7 generator per-process monotonik counter ile clock-backwards emniyeti saglar. Event id'ler yine unique kalir.
- **Architecture referans:** section 6.8

### Expo OTA vs native mismatch riski
- **Tarih:** 2026-04-21
- **Konu:** Mobile / CI
- **Detay:** EAS Update JS bundle'i push edebilir ama cihazda eski native olabilir. JS yeni native API bekliyorsa crash olur.
- **Cozum/Onlem:** `expo-updates` `runtimeVersion` policy kullan (`appVersion` veya `fingerprint`). Native degisiklik her zaman store build'i ile gider, OTA ile degil.
- **Architecture referans:** section 20.1

### Sender Keys uyelik degisiminde rotation zorunlu
- **Tarih:** 2026-04-21
- **Konu:** Crypto
- **Detay:** Grup uyeligi degisince (ekle/cikar) eski sender key hala gecerli olmamali; aksi halde eski uye yeni mesaji gorebilir.
- **Cozum/Onlem:** Membership degisiminde sender key rotation tetiklenir. Yeni key her uyeye Signal session'i uzerinden iletilir.
- **Architecture referans:** section 10.2

### Plaintext logging CI lint ile bloklu
- **Tarih:** 2026-04-21
- **Konu:** Backend / Core
- **Detay:** Log satirina mesaj body, phone number, OTP, token, attachment content yazmak privacy contract ihlali.
- **Cozum/Onlem:** CI lint rule (custom ESLint / regex) content-level logging'i bloklar. Logs event-level: user_id, device_id, action, timestamp, size. Trace id WebSocket frame'den backend'e propagate.
- **Architecture referans:** section 10.6, 18.4

### Supabase Realtime CPU pressure scale tetikleyicisi
- **Tarih:** 2026-04-21
- **Konu:** Backend / Scale
- **Detay:** Supabase Realtime Phoenix Channels tabanli ama managed; CPU pressure'da fan-out gecikir.
- **Cozum/Onlem:** p99 fan-out > 1 sn veya aylik spend > $10k -> self-hosted Phoenix'e gecis. Protokol ayni, istemci degismez.
- **Architecture referans:** section 19.1, 19.2

### Voice-preserving TTS consent zorunlu
- **Tarih:** 2026-04-21
- **Konu:** AI / Legal
- **Detay:** Voice clone TTS orijinal konusmacinin onayi olmadan kullanilirsa voice-likeness regulasyonu (EU AI Act, US state laws) riski.
- **Cozum/Onlem:** Feature Pro tier, aktive etmek icin orijinal konusmacidan explicit consent prompt. Consent log'u metadata olarak tutulur (plaintext'siz).
- **Architecture referans:** section 7.3

### Receipt batching — kotu yapilirsa jank
- **Tarih:** 2026-04-21
- **Konu:** Backend / Mobile
- **Detay:** Her mesaj icin delivery+read receipt gercek zamanli gonderilirse WS fan-out patlak verir.
- **Cozum/Onlem:** Delivered 200 ms debounce, read 400 ms debounce. Played sadece voice icin, >%90 playback veya replay trigger.
- **Architecture referans:** section 5.7

### Medya deduplication ciphertext hash ile
- **Tarih:** 2026-04-21
- **Konu:** Backend / Infra
- **Detay:** Forwarding cok yaygin; ayni meme binlerce kez upload edilirse storage patlar.
- **Cozum/Onlem:** Storage layer ciphertext SHA-256 dedup. Ayni bytes fiziksel olarak bir kere.
- **Architecture referans:** section 8.4

### AI provider fallback chain kritik
- **Tarih:** 2026-04-21
- **Konu:** AI Gateway
- **Detay:** Tek provider outage tum ceviri akisini durdurur.
- **Cozum/Onlem:** Her capability icin primary + secondary + on-device fallback. Gateway signed URL provider-agnostic rewrite.
- **Architecture referans:** section 7.4

---

## Skill referansi (hizli erisim)

Mobile perf / jank / bundle inceleme -> `react-native-best-practices` skill'i once calistirilir (FlashList, Hermes, re-render, bridge overhead, memory leak guideline'lari).

RN/Expo SDK yukseltme -> `upgrading-react-native` + `expo:upgrading-expo` birlikte. rn-diff-purge diff uygulanir, CocoaPods + Gradle + Expo config plugin eslenikleri kontrol edilir, WatermelonDB / libsignal binding'leri smoke-test edilir.

Yeni native modul (libsignal binding, platform API wrapper) -> `expo:expo-module` skill'i ile Modules API DSL.

EAS disinda GH-hosted simulator/emulator build -> `github-actions` (Callstack).

---

_(Kayitlar bu cizgiden sonra eklenir.)_
