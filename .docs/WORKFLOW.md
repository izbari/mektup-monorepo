# Calisma Akisi — Mektup

## Spec'ten deploy'a
1. **Toplanti/transkript** -> `meeting-agent` -> `.docs/meetings/MEETING-NNN.md`. Acik sorular + musteri kisitlari `CONSTITUTION.md`'ye islenir.
2. **`speckit.specify`** -> `.specify/specs/NNN-feature/spec.md` taslagi. **Jira'da ilgili Epic altinda MEK-NNN ticket bulunur veya olusturulur** (parent Epic baglantisi zorunlu).
3. **`speckit.clarify`** -> belirsiz gereksinimleri kapat.
4. **`speckit.plan`** -> solution-architect teknik plan uretir (data-model, contracts, fasing). `mektup_architecture.md` ile tutarlilik kontrolu burada.
5. **`speckit.analyze`** -> spec + plan coherence.
6. **`speckit.tasks`** -> domain-basli is paketleri (mobile / web / backend / core / ui-ux). **Her task bir MEK ticket'ina eslesir**; yeni kapsam cikarsa `createJiraIssue` ile yeni ticket (uygun Epic'e `parent` ile).
7. **Implementation** — agent'lara dagitim (AGENTS.md erisim matrisi).
   - **Basta:** `transitionJiraIssue` ile MEK ticket'i **Devam Ediyor** (id=21).
   - Bagimli olmayan tasklar paralel.
   - `packages/core` degisikligi tum client agent'lari etkiliyorsa once core, sonra client.
   - Contract-first: API degisiyorsa solution-architect mock kontratla client + server paralel.
   - Blocker/gerekli karar varsa `addCommentToJiraIssue` ile yorum ekle.
8. **UI/UX kontrol** (ui-ux-agent) — Figma varsa compliance, yoksa Mode B design decisions. Maks 3 iterasyon.
9. **Code review** (review-agent) — CONSTITUTION.md + mimari invariantlar + Turkce karakter + event sourcing safety.
10. **Architect review** — sadece mimari etkisi varsa (yeni pattern, dependency, contract, schema, cross-cutting concern). Paralel review-agent ile.
11. **Fix cycle** — review bulgusu -> implementing agent'a donus. 3 cycle'dan sonra escalate.
12. **QA** (qa-engineer) — functional, edge case, Turkce, multi-device convergence, offline scenarios.
13. **Merge** — review + architect (if needed) + QA signoff zorunlu.
14. **Deploy ve Jira kapatis:**
    - JS-only degisiklik -> EAS Update (OTA, staged rollout)
    - Native degisiklik -> EAS Build -> TestFlight / Internal Track -> %20 staged rollout -> %100 48 saatte
    - Web -> continuous (her merge ile)
    - Backend (Supabase) -> migration CI'da + 30 dk synthetic canary + production
    - **Merge tamam:** `transitionJiraIssue` ile MEK ticket'i **Tamam** (id=31). Kismen biten is `Devam Ediyor` kalir.

## Branch ve PR kurallari
- **Base:** `main`
- **Feature:** `feature/MEK-NNN-kisa-aciklama` (NNN Jira ticket numarasi)
- **Fix:** `fix/MEK-NNN-aciklama`
- **Hotfix:** `hotfix/MEK-NNN-aciklama` — sadece production incident icin, direkt `main`'den cikar
- **Spike/prototype:** `spike/konu` — merge edilmez, referans (Jira ticket gereksiz)
- **Commit formati:** `feat(MEK-NNN): <imperative kisa aciklama>` / `fix(MEK-NNN): ...` — her commit Jira ticket'ina referansli
- **PR title:** `[MEK-NNN] <imperative Turkce aciklama>` ("[MEK-190] Mesaj gonderme retry queue'suna exponential backoff ekle")
- **PR description:** neyi + neden (CONSTITUTION/architecture referansli) + nasil test edildi + `Jira: MEK-NNN` satiri
- Native native dosyalari (`ios/`, `android/`) asla manuel edit — Expo config plugin uzerinden

## Degisiklik talebi akisi (CR)
1. Talep `.docs/CHANGES.md` -> `CR-NNN`.
2. Etki analizi — hangi paket/uygulama/kontrat etkileniyor?
3. Gerekirse yeni spec veya mevcut spec revizyonu.
4. Implementation + review + QA.
5. Release notlarina CR referansli olarak eklenir.

## Ortam promosyonu
| Ortam | Amaç | Promosyon |
|-------|------|-----------|
| Dev | her engineer'a kendi Supabase projesi + EAS Dev Client | local |
| Preview | her PR icin ephemeral Supabase branch + EAS preview build | PR acilinca otomatik, merge/close ile destroy |
| Staging | production topolojisi mirror + synthetic traffic | `main` merge sonrasi CI auto-deploy |
| Production | multi-region US-East/EU-West/APAC-SE | staging canary 30 dk temiz -> auto-deploy (backend) / manuel gated (mobile staged rollout) |

## Release gate checklist (feature parity + quality)

Her release oncesi:
- [ ] Feature parity checklist (architecture section 22) — regresyon yok
- [ ] Sync engine invariant testleri gecer (monotonic chat_seq, no duplicate remote_id, replay safety)
- [ ] Crash-free session son 7 gun > 99.5%
- [ ] Cold start p95 < 2 sn (Pixel 4a equivalent)
- [ ] Turkce karakter end-to-end (input, display, search, sort) dogrulandi
- [ ] Plaintext logging lint temiz
- [ ] Rollback migration (her yeni DB migration icin) yazili + test edildi
- [ ] Changelog guncellendi
- [ ] AI quota degisikligi varsa entitlement endpoint guncel

## Iterasyon kurali
- UI/UX compliance: maks 3 iterasyon -> escalate
- Code review fix cycle: 3 iterasyon -> solution-architect escalate
- Spec clarify: 2 round belirsizlik kalirsa prompt engineer araya girer

## Zaman kayitlari
- Tarih referansi: `.docs/meetings/MEETING-*.md` + `CONSTITUTION.md > Mimari kararlar` + git log + Jira ticket gecmisi.
- Spec ID **ve** Jira Ticket ID commit mesajina eklenir: `feat(MEK-190): mesaj gonderme worker exponential backoff`.

## Jira lifecycle (detay `.docs/JIRA.md`)
- **Ise baslarken:** ilgili MEK ticket'i bul, status'u **Devam Ediyor**'a (id=21) `transitionJiraIssue` ile cevir.
- **Devam ederken:** blocker, kapsam degisikligi, karar bekleyen nokta varsa `addCommentToJiraIssue` ile yorum ekle — kodda birakma.
- **Tamamlandiginda:** merge sonrasi `transitionJiraIssue` ile **Tamam**'a (id=31) gec. Kismen biten is `Devam Ediyor` kalir.
- **Worklog:** Is bittiginde / oturum sonunda `addWorklogToJiraIssue` ile sure + kisa aciklama kaydedilir. Detay: `.docs/JIRA.md > Worklog`.
- **Yeni kapsam:** mevcut ticket'i sisirme, `createJiraIssue` ile yeni ticket ac (uygun Epic'e `parent` ile bagla).
- **Hard delete yok:** gereksiz ticket'lar "Tamam" transition'i ile soft-archive edilir; Jira UI'dan manuel silme gerekiyorsa `.docs/JIRA.md`'deki not'a bak.

## Git workflow (detay `.docs/GIT.md`)
- **Branch:** `feature/MEK-NNN-kisa-aciklama` (fix / docs / chore / hotfix ayri prefix'ler)
- **master'a direkt push yok** — tum degisiklikler feature branch + PR uzerinden
- **Merge stratejisi:** squash-and-merge — master'da tek commit = tek MEK ticket
- **Hotfix:** `master`'dan direkt, hizli review + squash merge + Jira Tamam

## Not
- Spec-kit akisi icin `/speckit.specify`, `/speckit.clarify`, `/speckit.plan`, `/speckit.analyze`, `/speckit.tasks`, `/speckit.implement` slash komutlari aktif.
- Ralph loop ile uzun surecek implementasyonlar `ralph-loop:ralph-loop` ile otonom ilerletilebilir.
- **RN surum yukseltme** icin `upgrading-react-native` + `expo:upgrading-expo` skill'leri birlikte kullanilir. PR oncesi `react-native-best-practices` ile regression check.
- **GH Actions native build pipeline** (EAS disinda fast PR simulator testi) icin `github-actions` (Callstack) skill'i referans.
