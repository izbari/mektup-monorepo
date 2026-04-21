# Mektup

WhatsApp sinifinda, **gorunmez AI ceviri katmani** tasiyan, **uctan uca sifreli** (E2EE) cok cihazli mesajlasma platformu. iOS + Android (Expo) + Web. Local-first, event-sourced, scale-target 10M+ MAU.

> Mimari tek gercek kaynak: **[`mektup_architecture.md`](./mektup_architecture.md)**

## Teknik ozet
- **Istemci:** Expo (React Native, New Architecture) + TypeScript strict + Tamagui + Zustand + WatermelonDB + FlashList. Web tarafi React Native Web + TanStack Router + WASM SQLite + OPFS.
- **Backend:** Supabase (MVP) -> sharded Postgres + Elixir Phoenix + R2 + NATS (scale).
- **E2EE:** Signal Protocol (X3DH + Double Ratchet + Sender Keys) — `libsignal`.
- **Cagrilar:** WebRTC P2P + LiveKit SFU + coturn TURN.
- **AI:** on-device plaintext islemleri + server-side signed-URL AI Gateway; ceviri, ASR, TTS, smart reply, summarization.

## Monorepo yapisi (planlanan)

```
apps/
  mobile/        # Expo RN (iOS + Android)
  web/           # React Native Web + TanStack Router
  server/        # Supabase config, edge functions, SQL migrations
packages/
  core/          # Sync engine, op queue, reducers, event projection
  ui/            # Tamagui components + design tokens
  signal/        # libsignal wrappers
  db/            # WatermelonDB schema + adapters
  transport/     # WebSocket client + REST fallback
  ai-client/     # AI gateway client + on-device fallbacks
.docs/           # Process docs (CONSTITUTION, WORKFLOW, AGENTS, dev-gotchas, TESTPLAN, meetings)
.specify/        # Spec-kit specs + templates + memory
.claude/         # Agent definitions, commands, skills, settings
```

## Hizli baslangic

```bash
# Paket kurulumu
pnpm install

# Mobile dev client (ilk kez ayrica EAS build gerekir)
pnpm --filter @mektup/mobile start

# Web
pnpm --filter @mektup/web dev

# Supabase local stack (edge function + migration)
pnpm --filter @mektup/server supabase:start
```

(Not: Yukaridaki komutlar planlanan monorepo icindir. Bu repo su an template asamasinda — source code henuz eklenmedi.)

## Agent altyapisi

Proje Claude Code agentic workflow ile yonetilir:
- **Agent tanimlari:** `.claude/agents/`
- **Slash komutlari (spec-kit):** `.claude/commands/`
- **Project skills:** `.claude/skills/` (`ui-ux-pro-max`, `vercel-react-native-skills`)
- **Plugin'ler:** expo, supabase, figma, superpowers, github, context7, feature-dev, code-review, typescript-lsp, security-guidance, commit-commands, claude-md-management, pr-review-toolkit, atlassian, ralph-loop, claude-code-setup

Agent rolleri: `project-manager`, `solution-architect`, `meeting-agent`, `mobile-agent`, `web-agent`, `backend-agent`, `core-agent`, `ui-ux-agent`, `review-agent`, `qa-engineer`. Detay: [`.docs/AGENTS.md`](./.docs/AGENTS.md).

## Is akisi

```
toplanti -> MEETING-NNN -> speckit.specify -> clarify -> plan -> analyze -> tasks
-> implement (mobile/web/backend/core) -> ui-ux review -> code review -> QA -> merge -> EAS Update / Build
```

Detay: [`.docs/WORKFLOW.md`](./.docs/WORKFLOW.md).

## Kritik invariantlar (ihlali olmaz)
- Server plaintext gormez (body, reaction, medya)
- Local-first: UI sunucu ack beklemez
- Event sourcing: `events` log + pure projection handlers
- UUIDv7 her yerde, hard delete yasak
- Per-chat total order: sunucu `chat_seq` atar
- Multi-device: 8 cihaz, primary yok, peer

## Guvenlik
- Secret'lar repo'da tutulmaz. `google-services.json`, `GoogleService-Info.plist` plaintext commit edilmez.
- Plaintext logging CI lint ile bloklanir.
- Private key cihazdan cikmaz; OS keystore (iOS Keychain, Android StrongBox, Web Crypto non-exportable).
- Backup password olmadan restore imkansiz — explicit privacy contract.

## Lisans

MIT (LICENSE dosyasina bakiniz)
