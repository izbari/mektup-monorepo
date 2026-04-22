# CONSTITUTION — Mektup

_Olusturulma: 2026-04-21 | Son guncelleme: 2026-04-21_

> Bu doküman `mektup_architecture.md`'deki mimari kararlarin ozetidir. Catisma varsa mimari doküman asil referanstir. Bu dosya degisiyorsa mimari dosyayi da guncelle.

## Proje ozeti
- **Proje adi:** Mektup
- **Musteri:** HexaOps (ic urun)
- **Kisa amac:** WhatsApp sinifinda, gorunmez AI ceviri ve ses-AI pipeline'li, uctan uca sifreli (E2EE) cok cihazli sohbet platformu. Platformlar: iOS, Android (Expo), Web.
- **Olcek hedefi:** MVP -> 10M+ MAU
- **Tek gercek kaynak:** `mektup_architecture.md`

## Teknik stack

### Istemci (mobile + web)
- **Framework:** Expo (React Native) — **New Architecture** (Fabric + TurboModules) temel kabul
- **Dil:** TypeScript strict mode
- **Monorepo:** pnpm workspaces — `apps/mobile`, `apps/web`, `packages/core`, `packages/ui`, `packages/signal`, `packages/db`, `packages/transport`, `packages/ai-client`
- **Yerel DB:** **WatermelonDB** (SQLite native mobile; WASM SQLite + OPFS web)
- **State:** Zustand (UI), WatermelonDB observables (kalici)
- **UI kit:** Tamagui
- **Navigation:** React Navigation (mobile), TanStack Router (web)
- **Liste render:** FlashList
- **Image:** `expo-image` (libjpeg-turbo + mem/disk cache)
- **Engine:** Hermes zorunlu

### Backend
- **MVP:** Supabase (Postgres, Realtime/Phoenix Channels, GoTrue Auth, Storage, Edge Functions)
- **Scale:** sharded self-hosted Postgres + Elixir Phoenix Channels + Cloudflare R2 + NATS JetStream + Redis (presence) + dedike push service
- **Gecis tetikleyici:** >$10k/mo Supabase spend, sustained realtime CPU pressure, per-shard tenancy ihtiyaci, veya HIPAA-sinifi compliance

### Sifreleme
- **Protokol:** Signal Protocol — **X3DH** + **Double Ratchet**, grup icin **Sender Keys**
- **Uygulama:** libsignal (JSI/TurboModule mobile, WASM web)
- **Yerel DB:** SQLCipher AES-256; DB key OS keystore (iOS Keychain `afterFirstUnlockThisDeviceOnly`, Android StrongBox)
- **Attachment:** AES-256-GCM, 4 MB chunk, chunk-basi nonce, per-device wrapped content key
- **App lock:** opsiyonel biometric foreground gate (storage key degil, UI gate)

### Gercek-zamanli
- **Transport:** WebSocket birincil, HTTP REST fallback
- **Ordering:** server-assigned per-chat **chat_seq** (advisory lock + unique index)
- **Conflict resolution:** Last-Writer-Wins, semantic guards; **delete absorbing**, reaction set-semantics. CRDT reddedildi.
- **Max devices per user:** 8

### Medya
- **Storage:** Supabase Storage (MVP) -> Cloudflare R2 (scale)
- **CDN:** Cloudflare, signed URL per-(attachment, device)
- **Cap:** 2 GB per attachment
- **Upload:** resumable multipart, 4 paralel chunk, durable byte offset
- **Image hazirlik:** 320px JPEG thumb + BlurHash device-basli
- **Voice:** Opus 32 kbps mono + 128-bucket waveform

### Cagrilar
- **Mimari:** WebRTC hibrit P2P + SFU
- **SFU:** LiveKit (per-region autoscale, 500 concurrent stream/node, 50+ participant)
- **TURN:** coturn fleet, Anycast, TLS:5349, UDP:3478, TCP:443 restrictive-network fallback
- **TURN auth:** HMAC-derived, 10 dk TTL
- **1:1 E2EE:** DTLS-SRTP; grup cagri MVP transport-encrypted, sender-keys group-call E2EE v2

### AI
- **Calisma yeri:** TUM plaintext-AI cihazda (E2EE gerekliligi)
- **Gateway:** stateless proxy — quota decrement, short-lived signed URL, provider fallback chain, plaintext asla loglamaz
- **Ceviri:** recipient-side, per-target-language, LRU cache (body_hash, src, dst)
- **Voice pipeline:** ASR -> MT -> TTS, on-device fallback (common pair'ler icin MLKit/ONNX)
- **Voice-preserving TTS:** Pro tier, **sender consent** zorunlu

### Auth
- **Primary:** Phone OTP (6 digit, 5 dk TTL), silent-SMS auto-fill
- **Secondary:** email magic link (web / recovery)
- **Attestation:** iOS DeviceCheck/App Attest, Android Play Integrity
- **Tokens:** access JWT 15 dk, refresh opaque 90 gun rotating one-shot, device_id kitli
- **Two-step:** kullanici PIN + opsiyonel recovery email

### Ortamlar ve release
- **Env:** Dev (per-engineer Supabase) / Preview (per-PR ephemeral) / Staging (canary) / Production (US-East, EU-West, APAC-SE active-active failover)
- **Release cadence:** Mobile weekly Monday, 20% staged rollout 48 saatte 100%
- **Web:** continuous
- **Backend:** 30 dk synthetic canary sonrasi

## Monorepo yapisi

```
mektup-monorepo/
  apps/
    mobile/        # Expo RN app (iOS + Android)
    web/           # React Native Web + TanStack Router
    server/        # Supabase config, edge functions, migrations
  packages/
    core/          # Business logic: sync engine, op queue, reducers, event types
    ui/            # Tamagui component library + design tokens
    signal/        # libsignal wrappers + ratchet state mgmt
    db/            # WatermelonDB schema + adapters (native + WASM)
    transport/     # WebSocket client + REST fallback + reconnect logic
    ai-client/     # AI gateway client + on-device fallbacks + caches
  .docs/           # Process docs (this folder)
  .specify/        # Spec-kit specs + templates
  .claude/         # Agent definitions, commands, skills
```

## Mimari kurallar (ihlali olmaz)

1. **Server plaintext gormez** — mesaj body, reaction, medya hepsi client'ta sifrelenir.
2. **Local-first** — her mutasyon once local DB + operation queue, sonra network. UI ack beklemez.
3. **Event sourcing** — `events` append-only log; projeksiyonlar pure function (previous_state, event).
4. **UUIDv7 her yerde** — PK ve natural sort cursor.
5. **Hard delete yasak** — her silme tombstone.
6. **Per-chat total order** — sadece server-assigned `chat_seq`.
7. **Idempotency** — tum mutating primitive'ler idempotent; event replay = replay-safe.
8. **Multi-device peer** — max 8 cihaz, primary yok; her cihaz bagimsiz identity key.
9. **Katman sinirlari:** business logic sadece `packages/core`; UI `apps/*`; DB erisimi sadece `packages/db` uzerinden; AI `packages/ai-client`. Cross-package import yonu aciklanmis (architecture section 16.1).
10. **Public API kontratlari** `.docs/contracts/` altinda dokumante edilir; degisiklik tum katmanlara duyurulur.
11. **Turkce karakter** — UTF-8, culture-aware compare, sort/filter Turkce-safe.

## Guvenlik kurallari

- **Kimlik:** Phone OTP birincil, e-posta ikincil, cihaz cross-signing QR-linking
- **Session:** 15 dk JWT + 90 gun refresh rotating; `device_id` kitli
- **Hassas veri at-rest:** SQLCipher AES-256 + OS keystore
- **Hassas veri in-transit:** TLS 1.3
- **Attachment:** per-attachment AES-GCM + per-device wrapped content key + SHA-256 integrity
- **Input validation:** boundary'de zorunlu (user input + external API)
- **CORS:** sadece gerekli origin'ler, signed URL scoping
- **Rate limit:** phone + IP + device fingerprint kombinasyonu
- **Secret depolama:** client EAS Secret, server Doppler/AWS Secrets Manager; repo'da asla

## Hata yonetimi

- **Global handler:** server ve client her iki tarafta zorunlu
- **Standart hata cevabi:** `{ success: boolean, message: string, errors: string[], code: string }`
- **Teknik detay kullaniciya acilmaz** — "Baglanti kuruluyor...", "Gonderilemedi, dokunup tekrar deneyin" gibi yumusak mesajlar
- **Retry:** exponential backoff + full jitter, 10 deneme sonrasi `dead` + UI retry affordance
- **Retryable:** network err, 5xx, 429 (Retry-After honored)
- **Non-retryable:** invalid signature, blocked recipient, revoked device

## Gozlem ve alarm esikleri

| Sinyal | Esik |
|--------|------|
| Cold start p95 | < 2 sn (alarm > 2 sn) |
| Chat open p95 | < 500 ms |
| Crash-free session | > 99.5% |
| WS reconnect rate | < 20% /dk |
| Event delivery < 30 sn | > 99.5% |
| Per-device sync lag p99 | < 2 dk |
| AI cost/hr | hard circuit-breaker 2x budget |

## Mimari kararlar

| Tarih | Karar | Gerekce |
|-------|-------|---------|
| 2026-04-21 | Expo + New Architecture | Solo-developer operability, OTA, tek codebase mobile |
| 2026-04-21 | WatermelonDB | SQLite underneath, lazy observables, built-in sync, MIT, Expo plugin |
| 2026-04-21 | Supabase MVP | Managed Postgres + Realtime + Storage + Auth; standart Postgres dump ile cikis |
| 2026-04-21 | Signal Protocol | Forward secrecy + post-compromise security, sender keys groups, endustri standardi |
| 2026-04-21 | Server-assigned chat_seq + LWW | CRDT yerine; owner-only edits + server ordering 95% conflict'i yok eder |
| 2026-04-21 | Client-heavy / backend-light | Local-first UX, p99 UI latency local disk I/O bagli, server stateless |
| 2026-04-21 | Tamagui | Shared design token mobile + web |
| 2026-04-21 | AI on-device (plaintext) | E2EE ile uyumlu tek yol; server sadece signed URL + quota |
| 2026-04-21 | pnpm monorepo | `@app/core` ayni paket mobile + web + node tests |
| 2026-04-21 | Firebase reddedildi | Firestore cikis migrasyonu her query rewrite gerektirir |
| 2026-04-21 | Realm reddedildi | RN version-coupled native modul + Atlas Sync vendor lock |
| 2026-04-21 | Raw SQLite reddedildi | Lazy observable + sync + migration elle yazmak chat app scope'unda maliyetli |
| 2026-04-22 | Jira MEKTUP (MEK) is takibi sistemi | Tum is paketleri, karar noktalari ve backlog Jira `MEK` projesinde takip edilir. Epic hiyerarsisi mimari ile hizalandi, detay `.docs/JIRA.md`. Commit + PR MEK-NNN ID ile referansli. |
| 2026-04-22 | Architecture coverage audit uygulandi | 23 section vs 140 mevcut ticket cross-reference sonucu: 48 yeni Story/Görev + 2 yeni Epic (MEK-201 Backup & Restore, MEK-202 Subscription & Monetization) eklendi. 10 duplicate ticket (MEK-152, 154, 156, 158, 160, 162, 164, 166, 168, 169) ve 12 bos Epic (MEK-18..29) "Tamam" status'una soft-archive edildi. |

## Musteri kisitlari

_(HexaOps ic urun — dis musteri kisitlari yok; ekle bu tabloya geldiginde)_

## Acik sorular

Bu sorulari kapatmak icin her biri Jira'da MVP Karar Noktalari Epic'i (MEK-17) altinda ticket olarak acildi (2026-04-22). Karar alindikca hem buradaki kutu isaretlenir hem ilgili Jira ticket'i **Tamam**'a cekilir.

- [ ] MVP launch hedef tarihi? -> **MEK-195**
- [ ] Pricing final (Free/Plus/Pro/Business) — architecture 17.1'deki rakamlar mi geciyor? -> **MEK-196**
- [ ] AI provider birincil secimi (OpenAI vs. DeepL vs. Anthropic) — cost/quality benchmark gerekli -> **MEK-197**
- [ ] Voice-preserving TTS regulasyon pozisyonu (EU AI Act, US state laws) — legal review -> **MEK-198**
- [ ] Channel/Communities v1'de mi v2'de mi? (Architecture section 22'de v2 olarak isaretli, teyit lazim) -> **MEK-199**
- [ ] Data residency gereksinimi (EU GDPR, TR KVKK) — production region stratejisi buna bagli -> **MEK-200**

## Figma referansi

- **Figma URL:** YOK (henuz yok)
- **Mod:** ui-ux-agent **Mode B — Design Decisions** moduna girer, `.docs/UIUX-*.md` uretir

## Iliskili dokumanlar

- `mektup_architecture.md` — tam mimari (1182 satir)
- `.docs/WORKFLOW.md` — is akisi
- `.docs/AGENTS.md` — agent erisim matrisi
- `.docs/JIRA.md` — Jira proje referansi + Epic haritasi + ticket lifecycle + worklog
- `.docs/GIT.md` — git workflow standardi (branch, commit, PR, merge)
- `.docs/TESTPLAN.md` — test seviyeleri
- `.docs/dev-gotchas.md` — bilinen tuzaklar
- `.docs/CHANGES.md` — CR log
