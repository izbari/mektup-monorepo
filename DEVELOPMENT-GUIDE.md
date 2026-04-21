# Mektup - Gelistirme Kilavuzu

Bu doküman gunluk gelistirme surecine odaklidir. Mimari ve ozellikler icin `mektup_architecture.md` asil kaynaktir.

## 1) Gelistirici kurulumu

### On kosullar
- **Node.js:** 20 LTS
- **pnpm:** 9+
- **iOS:** Xcode 15+, CocoaPods, iOS Simulator
- **Android:** Android Studio, SDK 34+, JDK 17
- **Supabase CLI:** local stack icin
- **EAS CLI:** `npm i -g eas-cli` (mobile build icin)
- **Docker:** local Supabase + integration tests

### Repo setup (monorepo kuruldugunda)
```bash
pnpm install
pnpm prepare             # husky + turbo cache
cp .mcp.example.json .mcp.json   # MCP server config (ornek)
```

Claude Code oturumunda:
- `.claude/settings.json` plugin'leri aktif ediyor olmali
- `mektup_architecture.md` + `.docs/CONSTITUTION.md` okunmus olmali

## 2) Yeni feature baslatma

1. **Toplanti -> MEETING:** `meeting-agent` ile transkripti `.docs/meetings/MEETING-NNN.md`'ye cevir. Acik soru/musteri kisiti varsa `CONSTITUTION.md`'ye eklet.
2. **Spec:** `/speckit.specify` -> `.specify/specs/NNN-feature/spec.md`
3. **Clarify:** `/speckit.clarify` ile belirsizlikleri kapat.
4. **Plan:** `/speckit.plan` -> solution-architect teknik plan + DTO/contract yazar. `.docs/contracts/` guncellenir.
5. **Analyze:** `/speckit.analyze` ile tutarlilik.
6. **Tasks:** `/speckit.tasks` -> domain basli is paketleri.
7. **Implement:** domain agent (`mobile-agent` / `web-agent` / `backend-agent` / `core-agent`) task'i alir.

## 3) Kod yazma kurallari

### Genel
- TypeScript strict — `any` gerekcesiz kullanilmaz
- Tum business logic `packages/core`'da; UI component'leri sadece dispatch eder
- Import yonu: `apps/*` -> `packages/*`; `packages/*` icinde `core` hicbir seye bagimli degil (zero platform import)
- Native dosyalari (`ios/`, `android/`) elle editlenmez — Expo config plugin uzerinden
- Public API: her endpoint/event type `.docs/contracts/` altinda dokumante

### Naming
- Component: `PascalCase`
- Hook: `useXxx`
- Event type: `domain.action` (`message.send`, `reaction.add`)
- Branch: `feature/NNN-kisa-aciklama` / `fix/NNN-aciklama`
- Commit: conventional commits, Turkce body: `feat(NNN): mesaj gonderme retry queue`

### Testing
- Yeni kod test edilir — `packages/core` coverage > %90, diger paketler > %70
- Sync engine degisimi property-based test ister
- Turkce karakter test edilir (her feature)

## 4) Calistirma

```bash
# Core logic test
pnpm --filter @mektup/core test

# Mobile dev (Expo Dev Client)
pnpm --filter @mektup/mobile start

# Web dev
pnpm --filter @mektup/web dev

# Supabase local
pnpm --filter @mektup/server supabase:start
pnpm --filter @mektup/server supabase:reset   # migration'lari bastan uygula
```

## 5) Debug ipuclari
- **Flipper** + React Native Devtools New Architecture'da sinirli — Hermes + `chrome://inspect` tercih edilir
- **Reactotron** WatermelonDB observable trace icin
- **Supabase Studio** local'de local Supabase + cloud'da dashboard
- **Sentry** replay + breadcrumb — cold start < first paint senaryolari
- Sync engine'de `DEV_INVARIANT_ASSERTIONS=true` env dev build'de aktif — violation anında throw

## 6) Commit + PR

```bash
# Commit
# (commit-commands plugin aktif; /commit komutu da kullanilabilir)
git commit -m "feat(NNN): mesaj gonderme worker exponential backoff"

# Push + PR
git push -u origin feature/NNN-kisa-aciklama
# gh pr create veya /commit-push-pr
```

PR title kisa ve imperative (Turkce). Body: neyi + neden (CONSTITUTION/architecture referans) + nasil test edildi + breaking mi.

## 7) Kapatma

- [ ] Lint + typecheck temiz
- [ ] Ilgili testler eklendi
- [ ] Review-agent: APPROVED
- [ ] QA: PASS
- [ ] Mimari karar varsa `CONSTITUTION.md > Mimari kararlar` guncel
- [ ] CR varsa `CHANGES.md` guncel
- [ ] Feature parity checklist etkilendiyse isaretli

## 8) Yaygin tuzaklar

`.docs/dev-gotchas.md` surekli guncellenir — gelistirme sirasinda kesfedilen surprizler oraya islenir.

## 9) Yardim

- **Mimari detay:** `mektup_architecture.md` (section numaralari referans)
- **Is akisi:** `.docs/WORKFLOW.md`
- **Agent sinirlari:** `.docs/AGENTS.md`
- **Test:** `.docs/TESTPLAN.md`
- **Kararlar:** `.docs/CONSTITUTION.md`
