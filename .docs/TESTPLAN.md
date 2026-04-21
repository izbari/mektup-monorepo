# Test Plani — Mektup

## Test stack
| Seviye | Arac | Kapsam |
|--------|------|--------|
| Unit (core) | **Vitest** | `packages/core/**` sync engine, op queue, reducers, event projection handler, LWW resolution, gap detection |
| Unit (client) | **Jest** + React Native Testing Library | `packages/ui/**`, `apps/mobile/**`, `apps/web/**` component + hook |
| Integration (backend) | **Vitest** + local Supabase stack (Docker) | Edge function, RLS policy, migration forward+rollback, realtime channel |
| E2E (mobile) | **Detox** | iOS Simulator + Android Emulator; send message, offline queue, multi-device, call flow |
| E2E (web) | **Playwright** | OPFS WASM SQLite, WebSocket reconnect, Web Push, WebRTC |
| Property-based | **fast-check** (Vitest) | Sync engine invariantlari — monotonic chat_seq, idempotency, replay safety |
| Performance | **Flashlight** (mobile), **Lighthouse** (web) | Cold start, chat open, scroll FPS, memory RSS |
| Crypto | custom vectors + libsignal test vectors | X3DH + Double Ratchet + Sender Keys; Signal wrapper'larinin bit-level uyumlulugu |

## Coverage hedefi
- `packages/core`: **> %90** (sync engine kritik)
- `packages/signal`, `packages/db`: **> %85**
- `packages/ui`, `apps/*`: **> %70** meaningful behavior coverage
- `apps/server`: edge function happy + 1 err path; RLS policy per-table pozitif + negatif

## Sync engine invariantlari (kritik)

Her yeni event tipi icin zorunlu test:
- [ ] Idempotency: ayni event 2 kez uygula -> tek etki
- [ ] Replay safety: event stream bastan replay -> ayni projection
- [ ] Monotonic sequence: ayni chat icinde iki event ayni chat_seq alamaz
- [ ] Gap detection: (N, N+2] aralik -> gap fill tetiklenir
- [ ] Ordering: sequence desc siralamada tutarlilik
- [ ] Concurrent edit: LWW winner = en buyuk chat_seq
- [ ] Delete absorbing: concurrent edit + delete -> delete kazanir
- [ ] Crash mid-sync: transaction rollback sonrasi re-pull ile ayni state
- [ ] Offline edit of un-sent msg: coalesced, edit event yok
- [ ] Device revoked during drain: queue preserved, re-pair sonrasi retry

## Turkce karakter testleri
- Input: ç, Ç, ğ, Ğ, ı, İ, ö, Ö, ş, Ş, ü, Ü — her text field
- Sort: `İstanbul < Izmir < Kayseri` culture-aware (tr-TR)
- FTS5: Turkce stemming + diacritic-insensitive arama
- Push notification: Turkce karakterli mesaj preview
- Encrypted storage + restore: roundtrip karakter kaybi yok

## Offline/adversarial senaryolar (qa-engineer calisma listesi)
1. Airplane mode + 10 mesaj + online -> hepsi sequence order'a girer
2. 2 cihaz es zamanli ayni mesaji edit eder -> server chat_seq LWW, log'da her iki edit history
3. WebSocket disconnect + 5 dk + reconnect -> gap pull, UI jank yok
4. Upload mid-way app kill -> resume from last acked offset
5. Device revoke wipe -> local DB temizlenir, re-pair akisi
6. Clock drift (cihaz saati 2 dk+ farkli) -> wall-clock suppressed, server time gosterilir
7. Yanlis backup password -> derivation fail, acik hata mesaji
8. Grup uyeligi degisir -> Sender Key rotation, yeni uye eski mesajlari goremez
9. Saat geri alinirsa -> UUIDv7 monotonik counter ile yine unique

## UAT
- Müsteri onayli senaryo listesi her feature icin (WhatsApp-parity checklist dahil)
- Staging ortaminda prompt engineer + musteri birlikte
- Feature flag ile controlled rollout

## Kabul kriterleri

Bir feature tamamlanmis sayilir:
- [ ] Unit testler yazildi ve geciyor
- [ ] Integration testler yazildi ve geciyor
- [ ] Sync engine invariantlari (ilgili eventler icin) test edildi
- [ ] E2E testi en az bir kritik akis icin yazildi
- [ ] Turkce karakter dogrulamasi yapildi
- [ ] Review-agent: APPROVED (veya APPROVED WITH CONDITIONS)
- [ ] QA verdict: PASS
- [ ] Crash-free hedefi korunuyor
- [ ] Cold start p95 regresyon yok
- [ ] Feature parity checklist guncel (eklendi/isaretlendi)
- [ ] UAT senaryolari musteri tarafindan onaylandi (launch-critical feature'lar icin)

## Test senaryosu sablonu

```
#### TC-NNN — Senaryo adi
- **Spec:** `.specify/specs/NNN-feature/spec.md`
- **Seviye:** unit / integration / E2E / property / UAT
- **On kosul:** ...
- **Adimlar:**
  1. ...
  2. ...
- **Beklenen sonuc:** ...
- **Architecture referans:** section X.Y (varsa)
- **Durum:** Yazilmadi / Gecti / Basarisiz
```

## CI ayaklari

GitHub Actions `mektup-ci.yml` sirasi (architecture section 18.2):
1. Lint + typecheck
2. Unit (Vitest + Jest)
3. Integration (local Supabase container)
4. Build (EAS Build preview on PR label, web Vite)
5. E2E — Detox (labeled PR) + Playwright (labeled PR)
6. Migration smoke (forward + rollback dry-run)
7. Bundle size diff (EAS + web)
8. Security lint (plaintext logging, hardcoded secret scan)
