# Agent Rolleri ve Erisim Haritasi — Mektup

## Genel kurallar
- Tum agentlar `mektup_architecture.md` ve `CONSTITUTION.md` kararlarina uyar
- API key/secret kaynak koda yazilmaz — client'ta EAS Secret, server'da Doppler/Supabase env
- Alan disi degisiklik yapilmaz (erisim matrisi altta)
- Turkce karakter uyumu tum katmanlarda dogrulanir
- Event sourcing + local-first + per-chat chat_seq mimarisi ihlal edilmez
- Plaintext server'a sizdirilmaz, plaintext loglanmaz
- **Jira sorumlulugu:** Her agent ise baslamadan Jira'daki ilgili MEK ticket'ini **Devam Ediyor**'a (transition id=21) cevirir; bitirince **Tamam**'a (id=31) cevirir. Blocker varsa `addCommentToJiraIssue` ile yorum ekler. Is bittiginde `addWorklogToJiraIssue` ile zamani kaydeder. Detay: `.docs/JIRA.md`.
- **Git sorumlulugu:** Her agent yeni is icin `feature/MEK-NNN-kisa-aciklama` branch'i acar (master'a direkt commit yok), commit mesajlari `feat(MEK-NNN): ...` / `fix(MEK-NNN): ...` formatinda, PR title `[MEK-NNN] ...`, merge stratejisi squash-and-merge. Detay: `.docs/GIT.md`.

## Erisim matrisi

| Agent | Yazma erisimi | Okuma erisimi | Model | Skill |
|-------|---------------|---------------|-------|-------|
| **project-manager** | `.docs/`, `.specify/specs/` (status alanlari) | tum proje | opus | — |
| **solution-architect** | `.docs/CONSTITUTION.md` (mimari kararlar tablosu), `.docs/contracts/`, `.docs/data-model.md`, `.specify/specs/` | tum proje + `mektup_architecture.md` | opus | context7 |
| **meeting-agent** | `.docs/meetings/**`, `CONSTITUTION.md` (sadece Acik Sorular + Musteri Kisitlari) | `.docs/**`, `.specify/**` | sonnet | atlassian (opsiyonel) |
| **mobile-agent** | `apps/mobile/**`, `packages/ui/**`, `packages/signal/**` (client binding), `packages/db/**` (schema + adapter), `packages/transport/**` (client), `packages/ai-client/**` | `.docs/**`, `.specify/**`, `packages/core/**` (read-only for signatures) | opus | vercel-react-native-skills, expo:* |
| **web-agent** | `apps/web/**`, `packages/ui/**` | `.docs/**`, `.specify/**`, `packages/core/**`, `packages/db/**` | opus | vercel-react-native-skills (RN Web), context7 |
| **backend-agent** | `apps/server/**` (Supabase config, edge functions, migrations, RLS) | `.docs/**`, `.specify/**`, `packages/transport/**` (contract signatures) | opus | supabase:* |
| **core-agent** | `packages/core/**` (sync engine, op queue, reducers, event types) | tum proje (read) | opus | — |
| **ui-ux-agent** | `.docs/UIUX-*.md` (Mode B), Figma MCP (Mode A) | tum proje | opus | ui-ux-pro-max, figma:* |
| **review-agent** | yok (agent-memory + PR comment) | tum proje | sonnet | code-review:*, pr-review-toolkit:* |
| **qa-engineer** | yok (agent-memory + QA report) | tum proje | opus | — |

## Ozel agent notlari

### mobile-agent
- **Expo Dev Client** kullanir, managed workflow'dan cikinca native dosyalar **elle duzenlenmez** (continuous native generation).
- WatermelonDB config plugin Expo'ya registered olur.
- `react-native-webrtc` + LiveKit RN SDK cagri icin.
- `expo-image-picker`, `expo-image`, `expo-local-authentication` (biometric lock) standart.
- APNs token + FCM token device register sirasinda kaydedilir.
- libsignal JSI/TurboModule uzerinden cagrilir — bridge marshalling kullanilmaz.

### web-agent
- React Native Web + Tamagui web adapter.
- WatermelonDB WASM SQLite + OPFS adapter kullanir.
- libsignal WASM bundle'i ilk paint sonrasi defer edilir (1.2 MB gzipped).
- Service Worker Web Push VAPID ile push handling yapar.
- TanStack Router file-based routing.
- WebAuthn biometric gate icin.

### backend-agent
- Sadece Supabase tarafi — Postgres migration (reversible + paired rollback), RLS policy, Edge Function, Realtime channel config, AI Gateway proxy fonksiyonu.
- **Plaintext AI islemez** — sadece signed URL issue + quota accounting + fallback routing.
- Per-chat advisory lock + unique (chat_id, event_id) index — sequence atamasi burada.
- Receipt debouncing (delivered 200ms, read 400ms) edge function icinde.
- Her migration icin rollback SQL CI'da kontrol edilir.

### core-agent
- Pure TypeScript, **zero platform import**. Node/RN/browser'da ayni calisir.
- Sync engine, operation queue, event projection handler'lari, LWW resolution, gap detection.
- Signal wrapper sadece imzalar — binding katmani `packages/signal/`.
- Property-based testler Vitest ile yazilir (fast-check). Invariantlar dev'de assert, prod'da Sentry.
- **HER** mutating primitive idempotent olacak.

### solution-architect
- `.docs/contracts/` altinda API kontratlarini tutar (endpoint path + method + DTO + status codes).
- Kontrat degisikligi tum agent'lara bildirilir, paralel implementation icin mock contract first.
- `CONSTITUTION.md > Mimari kararlar` tablosuna her karar tarihli + gerekceli eklenir.
- Kod yazmaz, pseudo-code + diagram + DTO yazar.

### ui-ux-agent
- **Mode A (Figma var):** compliance review, maks 3 iterasyon, sonra prompt engineer'a escalate.
- **Mode B (Figma yok):** `.docs/UIUX-NNN.md` uretir, frontend bunu referans alir.
- Tamagui token'lari (color, spacing, typography) tek yerden — `packages/ui/tokens/`.
- WhatsApp-parity UX beklentisi: tick state machine, reaction pill, sticky day separator, consecutive-message grouping 3 dk.

### review-agent
- Kod modifiye etmez, sadece PR comment + rapor uretir.
- `mektup_architecture.md` invariantlarini test eder (event sourcing, idempotency, chat_seq monotonlugu).
- Plaintext logging CI lint ile bloklanir — review burada da cross-check eder.
- **Verdict:** APPROVED / APPROVED WITH CONDITIONS / CHANGES REQUESTED

### qa-engineer
- Sync engine adversarial edge case listesi (architecture section 6.8) test seti.
- Turkce karakter end-to-end check.
- Offline scenario: airplane mode + send + reconnect.
- Multi-device convergence: 2 cihaz + ayni chat + karisik siralama mesaj gonder.

## Cross-agent kurallari

- **API kontrat degisikligi** -> solution-architect onayi + mobile-agent + web-agent + backend-agent bildirim.
- **Event type eklenmesi/degistirilmesi** -> core-agent + backend-agent + tum client agent'lar bilgilendirilir, schema migration + projection handler + replay safety test yazilir.
- **DB schema migration** -> backend-agent yazar, solution-architect onaylar, paired rollback zorunlu.
- **Security-sensitive degisiklikler** (key mgmt, session, RLS, AI gateway) solution-architect + review-agent double review.
- **Tier/quota degisikligi** -> billing + entitlement endpoint + AI Gateway accounting es zamanli.
- **Feature parity checklist** (architecture section 22) release gate — eksik feature listelenir ve kabul edilir veya planlanir.

## Iterasyon kurali
- UI/UX compliance: maksimum 3 iterasyon (Mode A veya Mode B).
- Code review fix cycle: 3'ten fazla donusum varsa solution-architect'e escalate.
