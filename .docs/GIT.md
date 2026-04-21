# Git Workflow Standardi — Mektup

Git uzerinde yapilan her is bu standarda uyar. Temel amac: her commit bir Jira MEK ticket'ina baglidir, master'a merge edilmeden once review + test gecer, gecmis okunabilir kalir.

## Base ve remote'lar

| Alan | Deger |
|------|-------|
| Default branch | `master` |
| Primary remote | `origin` (GitHub) |
| Mirror remote | `bitbucket` (yedek) |

`master`'a **dogrudan push yasak** (hotfix disinda, asagida). Tum degisiklikler feature branch + PR uzerinden gider.

## Branch isimlendirme

| Tip | Format | Kullanim |
|-----|--------|----------|
| Feature | `feature/MEK-NNN-kisa-aciklama` | Yeni ozellik, ticket Hikaye/Görev |
| Fix | `fix/MEK-NNN-kisa-aciklama` | Hata duzeltme, ticket Hata |
| Hotfix | `hotfix/MEK-NNN-kisa-aciklama` | Production'daki canli sorun, direkt `master`'dan cikar |
| Spike | `spike/konu-adi` | Prototip/arastirma, merge edilmez, Jira ticket opsiyonel |
| Docs | `docs/MEK-NNN-kisa-aciklama` | Sadece dokumantasyon degisikligi |
| Chore | `chore/MEK-NNN-kisa-aciklama` | Version bump, konfigurasyon, refactor (davranis degismiyor) |

**Kurallar:**
- MEK-NNN zorunlu (spike haric)
- Kisa aciklama kebab-case, 3-5 kelime, Turkce karakter yok (ingilizce veya transliterasyon)
- Ornek: `feature/MEK-190-chat-seq-advisory-lock`

## Commit mesaji (Conventional Commits + MEK)

### Format
```
<type>(MEK-NNN): <imperative kisa aciklama>

<opsiyonel govde — neyi + neden, Turkce>

Architecture referans: section X.Y (varsa)
Constitution referans: madde N (varsa)
Jira: MEK-NNN
```

### Type listesi
| Type | Kullanim |
|------|----------|
| `feat` | Yeni ozellik |
| `fix` | Hata duzeltme |
| `docs` | Sadece dokumantasyon |
| `style` | Formatting (kod davranisi degismez) |
| `refactor` | Davranis degismez, yapi degisir |
| `perf` | Performans iyilestirme |
| `test` | Test ekleme/duzeltme |
| `chore` | Build, dependency, config |
| `ci` | CI/CD konfigurasyonu |

### Ornekler
```
feat(MEK-190): chat_seq advisory lock implementasyonu

- per-chat advisory lock ile sequence atomik atanir
- (chat_id, chat_seq) unique index eklendi
- property-based test 10000 iterasyon temiz

Architecture Section 5.3, Constitution madde 6.
Jira: MEK-190
```

```
fix(MEK-213): mesaj retry'da exponential backoff jitter duzeltildi

Aynı anda baglanti gelen 10k cihaz thundering herd uretiyordu.
Full jitter ile spread edildi.

Jira: MEK-213
```

```
docs(MEK-251): Jira + Git workflow dokumanlari
```

**Onemli kurallar:**
- **MEK-NNN commit basligina zorunlu eklenir** — CI lint bunu kontrol edebilir.
- Imperative mood (`ekle`, `duzelt`, `kaldir`) — past tense degil.
- Ilk satir 72 karakter alti.
- Body sadece `why` aciklar (`what` diff'te zaten gorulur).
- `--no-verify` yasak (hook'lari atla ma).
- `--amend` sadece push edilmemis commit'te, sonrasinda yeni commit at.

## PR kurallari

### Ne zaman acilir
- Feature/fix/docs tamamlandiktan sonra
- En az 1 commit, lint + typecheck temiz

### Baslik
```
[MEK-NNN] <imperative Turkce kisa aciklama>
```
Ornek: `[MEK-190] chat_seq advisory lock ile total ordering`

### Body sablonu
```markdown
## Ozet
- Ne yapildi, neden
- Architecture referans: Section X.Y
- Constitution referans: madde N

## Nasil test edildi
- [ ] Unit: ...
- [ ] Integration: ...
- [ ] E2E: ...
- [ ] Manuel: Turkce karakter + offline
- [ ] Performance: cold start regresyonu yok

## Riskler
- ... (breaking change, migration, ...)

Jira: MEK-NNN
```

### Review
- Review-agent gerekli; architect-review sadece mimari etki varsa (yeni pattern, contract, schema)
- QA signoff zorunlu (smoke + happy path + Turkce karakter)
- 3 review cycle'dan sonra solution-architect'e escalate

## Merge stratejisi

### Secim
Feature/fix icin **squash and merge** kullanilir.

**Gerekce:**
- Tek PR = tek commit master'da -> gecmis okunabilir
- PR icindeki WIP commit'ler master'da kaybolur
- Her master commit'i bir MEK ticket'ina net baglidir

### Squash commit mesaji
PR title + numarasi ile olusur:
```
[MEK-190] chat_seq advisory lock ile total ordering (#42)
```

Body PR description'indan kopyalanir.

### Istisnalar
- **Merge commit:** buyuk integration PR'larda (multi-ticket, cross-package) kronolojik gecmis onemli ise
- **Rebase:** spike branch'leri cleanup icin (ama zaten merge edilmezler)

## Rebase vs merge (pre-PR)

Feature branch master'in gerisinde kalmissa:
- **Kucuk fark (< 10 commit):** `git rebase origin/master` tercih edilir — gecmis duz
- **Buyuk fark veya conflict riskli:** `git merge origin/master` ile merge commit

Force-push sadece kendi feature branch'ine `--force-with-lease` ile. `master`'a asla force-push yok.

## Hotfix akisi

Production'da incident var:
1. `master`'dan `hotfix/MEK-NNN-aciklama` branch
2. Minimal fix (no refactor, no cleanup)
3. Commit: `fix(MEK-NNN): <aciklama>` (tek commit tercih)
4. PR + hizli review + squash merge
5. EAS Update (JS-only) veya hotfix native build
6. Jira ticket Tamam
7. Post-incident review gerekirse ayri PR

## Worktree (opsiyonel)

Paralel is icin `superpowers:using-git-worktrees` skill'i kullanilabilir:
- Ana workspace'te feature branch calisirken
- Ikinci worktree'de hotfix branch'ini review etmek
- Context kaybi olmaz

Basit single-feature isinde worktree gereksiz.

## Tag'leme

Release tag'leri: `v0.1.0`, `v1.2.3` — semantic versioning.
EAS Build sirasinda otomatik tag uretilir (configurable).

## Gerekli degilken yapilmayacaklar

- `git push --force master` (veya --force-with-lease) — yasak
- `git reset --hard HEAD~` (uncommitted work kaybolur)
- `git commit --no-verify` (hook'lari atlama)
- `git checkout .` veya `git restore .` toplu discard (kontrol edilmemis)
- Amend edilmis ve push edilmis commit'e bir daha amend (rebase forcing'e yol acar)
- Secret/API key'li commit — `.gitignore` + pre-commit hook ile engellenir

## Pre-commit hook (onerilen, CI destekleyicisi)

- Lint + typecheck on staged files
- Plaintext logging lint rule (Constitution madde)
- Commit message format validator (MEK-NNN basligi)
- Secret scan (AWS key, private key pattern)

Hook'lar `husky` ile yonetilir (kurulumu Platform Bootstrap altinda MEK-175 CI pipeline'in parcasi).

## Gecmis okunabilirligi

Commit'ler master'da **her zaman** su formatta olmali:
```
<type>(MEK-NNN): <kisa aciklama> (#PR-NUM)
```

`git log --oneline` cikisi tek bakista neyin niye degistigini gostermeli.

## Ayni anda birden fazla agent

- Her agent kendi feature branch'ini acar, conflict olmamasi icin dosya alanina dikkat (AGENTS.md erisim matrisi)
- Cross-package degisiklik gerekiyorsa solution-architect once koordinasyon PR'i acar (contract), sonra domain agent'lari o PR'dan branch olusturur
- Packages/core degisikligi tum client agent'lari etkiliyorsa once core merge edilir, sonra client branch'leri rebase eder

## Iliskili dokumanlar

- **Jira entegrasyonu:** `.docs/JIRA.md` (ticket lifecycle, commit ile eslesme, worklog)
- **Calisma akisi:** `.docs/WORKFLOW.md` (spec'ten deploy'a)
- **Agent erisim matrisi:** `.docs/AGENTS.md`
- **Gunluk kilavuz:** `DEVELOPMENT-GUIDE.md`
