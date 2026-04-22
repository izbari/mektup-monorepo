# Mektup - Agent Calisma Kilavuzu

## Proje kimligi
- **Proje adi:** Mektup
- **Musteri:** HexaOps (ic urun)
- **Kisa amac:** WhatsApp sinifinda, gorunmez AI ceviri katmani tasiyan, uctan uca sifreli (E2EE) sohbet platformu. iOS + Android (Expo) + Web.
- **Olusturulma tarihi:** 2026-04-21
- **Takim lideri:** Kutay Erdogan
- **Prompt engineer:** Kutay Erdogan
- **Olcek hedefi:** MVP'den 10M+ MAU'ya
- **Mimari referans:** `mektup_architecture.md` (tek gercek kaynak, 1182 satir)

## Oturum baslangicinda okunacaklar
1. `mektup_architecture.md` — mimari kararlar burada, geri donulemez kararlar bolumune (section 1) mutlaka bak
2. `.docs/CONSTITUTION.md` — ozet + proje kurallari
3. `.docs/AGENTS.md` — agent sinirlari
4. `.docs/WORKFLOW.md` — calisma akisi
5. `.docs/JIRA.md` — Jira proje referansi + Epic haritasi + ticket lifecycle + worklog
6. `.docs/GIT.md` — git standardi (branch, commit, PR, merge)
7. `.docs/dev-gotchas.md` — bilinen tuzaklar
8. `.docs/meetings/` altindaki en son `MEETING-*.md` (varsa)
9. `.specify/specs/` altindaki aktif spec dosyalari

## Teknoloji stack (mimari karar — degistirme)

### Istemci (mobile + web)
- **Framework:** Expo (React Native) — **New Architecture** (Fabric + TurboModules) zorunlu
- **Dil:** TypeScript strict mode, her yerde
- **Yerel DB:** WatermelonDB (SQLite uzerinde, native mobile; WASM SQLite + OPFS web)
- **State:** Zustand (gecici UI state) + WatermelonDB observables (kalici state) — Redux kullanilmaz
- **Stil:** Tamagui (native styles mobile, CSS web, paylasilan design token)
- **Navigation:** React Navigation (mobile), TanStack Router (web)
- **Liste render:** FlashList (Shopify) — FlatList kullanilmaz
- **E2EE:** Signal Protocol (libsignal; JSI/TurboModule mobile, WASM web)
- **Monorepo:** pnpm; `apps/mobile`, `apps/web`, `packages/core`, `packages/ui`, `packages/signal`, `packages/db`, `packages/transport`, `packages/ai-client`

### Backend
- **MVP:** Supabase (Postgres, Realtime/Phoenix Channels, Auth/GoTrue, Storage, Edge Functions)
- **Scale:** Self-hosted sharded Postgres + Elixir Phoenix Channels + Cloudflare R2 + NATS JetStream
- **Cikis kapisi (exit strategy):** standart Postgres dump + Phoenix protokol ayni, istemci degismeden gecis

### Medya ve Cagrilar
- **Medya:** S3-uyumlu object store + CDN; AES-256-GCM attachment-basi, chunk-basi nonce
- **Cagrilar:** WebRTC; 1:1 P2P (TURN fallback), grup cagri LiveKit SFU, coturn TURN fleet

### Test
- **Core logic:** Vitest
- **Mobile E2E:** Detox
- **Web E2E:** Playwright
- **Prop-based:** sync engine invariantlari (dev build'de assert, prod'da Sentry'ye rapor)

### DevOps
- **CI/CD:** GitHub Actions
- **Mobile build:** EAS Build + EAS Update (JS OTA)
- **DB migration:** Supabase CLI (her forward migration icin rollback scripti zorunlu)
- **Gozlemlenebilirlik:** Sentry (crash + perf), Prometheus + Grafana + Loki (backend), Firebase Performance
- **Ortamlar:** Dev (her engineer'a Supabase projesi) / Preview (PR-basi ephemeral) / Staging / Production (multi-region)

## Standart akis (speckit + review + Jira)
1. Toplanti/transkript -> `MEETING-NNN.md` (meeting-agent)
2. `speckit.specify` — spec taslagi + **Jira ticket bul/olustur** (uygun MEK-NNN Epic altinda)
3. `speckit.clarify` — belirsizlikleri kapat
4. `speckit.plan` — teknik plan (solution-architect)
5. `speckit.analyze` — tutarlilik kontrolu
6. `speckit.tasks` — is paketleri; **her task bir MEK ticket'ina eslesir**
7. Implementasyon (mobile-agent / web-agent / backend-agent / core-agent) — **baslarken Jira ticket'i `Devam Ediyor`'a (id=21) al**
8. UI/UX kontrol (ui-ux-agent, en fazla 3 iterasyon)
9. Code review (review-agent) ve gerekiyorsa architect review (solution-architect)
10. QA (qa-engineer)
11. Merge + EAS Update veya native build — **merge sonrasi Jira ticket'i `Tamam`'a (id=31) al**

## Jira entegrasyonu (ozet, detay `.docs/JIRA.md`)
- **Proje:** MEKTUP (`MEK`), cloudId `27133666-4d2d-4ea8-98ff-3ccd3c39936c`
- **Commit formati:** `feat(MEK-NNN): kisa aciklama` / `fix(MEK-NNN): ...` — her commit MEK ticket'ina referansli
- **PR title:** `[MEK-NNN] <kisa aciklama>`
- **PR body:** architecture/constitution referansi + `Jira: MEK-NNN` satiri
- **Agent sorumlulugu:** Her agent ise baslarken ilgili MEK ticket'ini **Devam Ediyor**'a, bitirince **Tamam**'a transition eder. Blocker varsa yorum ekler.
- **Worklog:** Is bittiginde veya oturum sonunda `addWorklogToJiraIssue` ile `timeSpent` ve kisa aciklama girilir (detay `.docs/JIRA.md > Worklog`).
- **Hard delete yok:** Silme yerine "Tamam" transition (soft-archive). Gercek silme Jira UI'dan manuel.
- **Yeni kapsam:** Mevcut ticket'i sisirme, yeni ticket ac (uygun Epic'e `parent` ile bagla).

## Git workflow (ozet, detay `.docs/GIT.md`)
- **Base branch:** `master` — dogrudan push yasak
- **Feature branch:** `feature/MEK-NNN-kisa-aciklama` (fix/docs/chore/hotfix benzer)
- **Commit:** Conventional Commits + MEK ID zorunlu: `feat(MEK-190): ...`
- **PR:** `[MEK-NNN] <aciklama>` title, body'de `Jira: MEK-NNN`
- **Merge:** squash-and-merge (feature/fix icin) — master'da tek commit = tek ticket
- **Hotfix:** `hotfix/MEK-NNN-...` master'dan cikar, hizli review + squash merge

## Ortak kurallar (sozesmesiz ihlali olmaz)
- **Server plaintext gormez.** Mesaj body'si, reaction metadatasi, medya — hepsi client'ta sifrelenir. Server ciphertext + minimum routing metadata ile calisir.
- **Local-first.** Her kullanici-gorunur mutasyon once local DB'ye yazilir, sonra `operation queue`'ya enqueued olur. UI sunucu onayi beklemez.
- **Event sourcing.** `events` tablosu tek yazma log'u; messages/reactions/receipts bunun projeksiyonu. Pure projection handler'lar replay-safe.
- **UUIDv7 her yerde.** PK ve dogal sort cursor. Monoton artan integer PK kullanilmaz (hot-write shard riski).
- **Silme = tombstone.** Hard delete yok; `deleted_at` alani var.
- **Per-chat sequence.** Sunucu atomik olarak chat_seq atar; istemci siralamada sadece buna guvenir. Wall-clock sadece display icin.
- **Turkce karakter uyumlulugu.** UTF-8 encoding, culture-aware string compare, nvarchar (varchar degil), Türkçe karakterli input/output test edilir.
- **API key/secret kaynak koda yazilmaz.** Client'ta `expo-constants` + EAS Secret, server'da Supabase env / Doppler. `.env` asla commit edilmez.
- **Iclerde plaintext loglama yasak.** Log event-level'dir: user_id, device_id, action, timestamp, size. Icerik logu CI lint ile bloklanir.
- **Private key cihazdan ayrilmaz.** iOS Keychain / Android StrongBox / Web Crypto non-exportable key. Backup'lara plaintext key yazilmaz.

## Mimari karar loglama
Geri donulemez veya olcekli etkisi olan her karar `.docs/CONSTITUTION.md > Mimari kararlar` tablosuna eklenir. `mektup_architecture.md`'den sapan bir karar aliniyorsa spec + toplanti referansi ile birlikte islenir.

## Plugin ve skill altyapisi
- Aktif plugin'ler: `.claude/settings.json` — expo, supabase, frontend-design, figma, superpowers, github, context7, feature-dev, code-review, typescript-lsp, security-guidance, commit-commands, claude-md-management, pr-review-toolkit, atlassian, ralph-loop, claude-code-setup + **Callstack** bundle (github, github-actions, react-native-best-practices, upgrading-react-native, react-native-brownfield-migration).
- Proje-ici skill'ler: `.claude/skills/` — sadece `ui-ux-pro-max` ve `vercel-react-native-skills`.
- Global skill'ler (plugin'lerden): `expo:*`, `supabase:*`, `figma:*`, `speckit.*`, `superpowers:*`, `feature-dev:*`, `code-review:*`, `pr-review-toolkit:*`.

### Mobil icin birincil skill'ler
- **`vercel-react-native-skills`** — genel RN + Expo performans
- **`react-native-best-practices`** (Callstack) — FPS, TTI, bundle size, memory leaks, re-render, Hermes, JS thread, FlashList, bridge overhead (mobile-agent hot path'leri)
- **`upgrading-react-native`** (Callstack) — RN surum yukseltme (rn-diff-purge, CocoaPods/Gradle, Expo SDK eslenik bump)
- **`expo:expo-dev-client`**, **`expo:expo-module`**, **`expo:upgrading-expo`**, **`expo:expo-deployment`**, **`expo:expo-cicd-workflows`** — Expo islemleri
- **`github-actions`** (Callstack) — RN iOS Simulator + Android Emulator cloud build workflow'lari (EAS disinda GH Actions native test build'i icin)
- **`react-native-brownfield-migration`** (Callstack) — su an gerekli degil; ileride native host app'e embed gerekirse referans

## Not
Bu dosya `mektup_architecture.md` ozetine ve calisma kurallarina referanstir. Detay icin her zaman mimari dokumana git.
