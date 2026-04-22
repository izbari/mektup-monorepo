# Jira Entegrasyonu — Mektup

Mektup projesinin is takibi **Jira MEKTUP projesi** uzerinden yurutulur. Bu dosya entegrasyonun tek referansidir; diger dokumanlar (CLAUDE.md, WORKFLOW.md, AGENTS.md, CONSTITUTION.md) buraya isaret eder.

## Erisim

| Alan | Deger |
|------|-------|
| Workspace | `hexaops.atlassian.net` |
| Cloud ID | `27133666-4d2d-4ea8-98ff-3ccd3c39936c` |
| Proje anahtari | `MEK` |
| Proje URL'si | https://hexaops.atlassian.net/browse/MEK |
| Claude Code MCP | `plugin:atlassian:atlassian` |

## Issue tipleri ve durumlar

| Tip | Hiyerarsi | Kullanim |
|-----|-----------|----------|
| Epik | 1 | Ozellik veya altyapi kumesi (MVP kapsam baslik) |
| Hikaye | 0 | Kullanici acisindan anlam tasiyan is parcasi |
| Görev | 0 | Teknik is (altyapi, integration, migration) |
| Hata | 0 | Bug raporu |
| Subtask | -1 | Hikaye/Görev alt isleri (gereksiz yere kullanma) |

**Durumlar ve transition ID'leri:**
- **Yapılacaklar** (id=11) — backlog'da
- **Devam Ediyor** (id=21) — uzerine alindi, kod yaziliyor
- **Tamam** (id=31) — merge + QA tamamlandi

## Epic haritasi

### Platform ve altyapi
| Key | Baslik | Kapsam |
|-----|--------|--------|
| MEK-14 | Platform Bootstrap | Monorepo, Expo mobile/web, Supabase dev, CI/CD, observability |
| MEK-15 | E2EE (Signal Protocol) | X3DH, Double Ratchet, Sender Keys, SQLCipher, attachment crypto |
| MEK-16 | Sync Engine & Event Sourcing | op queue, chat_seq, LWW, data model, invariant tests |
| MEK-148 | Technical Infrastructure & Integrations | Servis katmani, entegrasyon, performans |

### Ozellik Epic'leri
| Key | Baslik | Architecture ref |
|-----|--------|------------------|
| MEK-119 | Onboarding & Authentication | Section 14 |
| MEK-121 | Chat List & Navigation | Section 12.2 |
| MEK-123 | New Chat & Group Creation | Section 12 |
| MEK-125 | 1:1 Messaging | Section 5 |
| MEK-127 | Voice Message Translation Flow | Section 7.2 |
| MEK-130 | Group Chat | Section 5 + 10.5 |
| MEK-131 | Media & File Sharing | Section 8 |
| MEK-133 | Search | Section 12 |
| MEK-135 | Voice & Video Calling | Section 9 |
| MEK-138 | Anılar (Status/Stories) | Section 22 |
| MEK-140 | Notifications | Section 12 |
| MEK-142 | Settings | Section 13 |
| MEK-144 | Translation Settings (+ AI Gateway) | Section 7 |
| MEK-146 | Profile & Privacy | Section 13.2 |

### Yonetim / destek
| Key | Baslik | Kapsam |
|-----|--------|--------|
| MEK-17 | MVP Karar Noktalari | Constitution'daki 6 acik stratejik karar |
| MEK-150 | QA, Bugfix & Release Prep | Test senaryolari, release gate |
| MEK-201 | Backup & Restore | Section 15 — yedekleme sistemi (yeni) |
| MEK-202 | Subscription & Monetization | Section 17 — uyelik ve faturalama (yeni) |

## Architecture section -> Epic map

| Section | Epic |
|---------|------|
| 2 System Architecture | MEK-16, MEK-148 |
| 3 Technology Decisions | MEK-14 |
| 4 Data Modeling | MEK-16 (yeni story'ler) |
| 5 Messaging System | MEK-125, MEK-130 |
| 6 Local-First Sync | MEK-16 |
| 7 AI Integration | MEK-144, MEK-127 |
| 8 Media System | MEK-131 |
| 9 Voice & Video | MEK-135 |
| 10 Security/Privacy | MEK-15, MEK-146 |
| 11 Performance | MEK-148 |
| 12 UI/UX | MEK-121, MEK-125, MEK-140 |
| 13 Settings | MEK-142, MEK-146 |
| 14 Authentication | MEK-119 |
| 15 Backup/Restore | MEK-201 |
| 16 Web Architecture | MEK-14, MEK-15 (web tarafi) |
| 17 Subscription | MEK-202 |
| 18 DevOps | MEK-14 |
| 21 Failure Modes | MEK-16, MEK-150 |
| 22 Feature Parity | MEK-138, parity disinda MEK-199 karar |

## Ticket yasam dongusu (agent akisi)

### Ise baslarken (ZORUNLU)
1. Jira'da ilgili MEK-NNN ticket'ini bul (summary, spec id veya branch ismi ile).
2. Status **Yapılacaklar** ise `transitionJiraIssue` ile **Devam Ediyor**'a (id=21) gec.
3. Gerekirse `assignee_account_id` set et.
4. Yeni bilgi / blocker varsa `addCommentToJiraIssue` ile yorum ekle.

### Calisma sirasinda
- Blocker, karar bekleyen nokta veya kapsam degisikligi varsa **yorum ekle** — sadece kod'da birakma.
- Subtask uretmek genelde gereksiz; gerek varsa olustur + parent Hikaye/Görev'e `parent` field'i ile bagla.
- Yeni kapsam cikarsa: **yeni ticket ac** (mevcut ticket'i sisirme), uygun Epic'e `parent` ile link ver.

### Tamamlandiktan sonra (ZORUNLU)
1. **Commit:** `feat(MEK-NNN): <imperative kisa aciklama>` / `fix(MEK-NNN): ...`
2. **PR title:** `[MEK-NNN] <kisa aciklama>`
3. **PR body:** Architecture + Constitution referansi + test plani + `Jira: MEK-NNN` satiri.
4. Merge sonrasi: `transitionJiraIssue` ile **Tamam**'a (id=31) gec.

### Kapatilamayacak durum (incomplete)
- Tests failing -> Jira **Devam Ediyor** kalir, yorum + blocker note eklenir.
- Partial implementation -> **Devam Ediyor** kalir.
- Asla ister konstrukt bitmeden **Tamam**'a alma.

## Yeni ticket olusturma kurallari

- **Projekey:** her zaman `MEK`
- **issueTypeName:** Epik / Hikaye / Görev / Hata / Subtask
- **parent:** Hikaye ve Görev icin zorunlu (uygun Epic'e bagla; orphan yaratma).
- **summary:** Turkce, imperative, 80 karakter alti. Teknik jargon sinirli.
- **description:** **Tek paragraf, duz Turkce**, normal insan diliyle. Teknik ayrintilar icin parantez ici.
- **contentFormat:** `markdown` (uyumlu ama escape dikkat).
- **Reporter:** default (mevcut user). Bulk rename isleri icin sadece `reporter = Kutay Erdogan` olanlar editlenir.

## Commit + PR format

### Commit mesaji
```
feat(MEK-190): chat_seq advisory lock implementasyonu

- per-chat advisory lock ile sequence atomik atanir
- (chat_id, chat_seq) unique index eklendi
- property-based test 10000 iterasyon temiz

Architecture Section 5.3, Constitution madde 6.
Jira: MEK-190
```

### PR body sablonu
```markdown
## Ne degisti
- ...

## Neden
Architecture Section X.Y + Constitution madde N.
Jira: MEK-NNN (+ varsa ilgili diger ticket'lar)

## Nasil test edildi
- Unit: ...
- Integration: ...
- E2E: ... (varsa)
- Manuel: Turkce karakter + offline senaryo
```

## Yasak ve bilinen tuzaklar

- **Hard delete yok:** Jira MCP `deleteIssue` sunmaz. Gereksiz ticket "Tamam"a alinir (soft-archive). Gercek silme icin Jira UI'dan manuel islem gerekir. Duplicate/legacy temizlik icin `transitionJiraIssue` + id=31 kullan.
- **Description newline escape:** Markdown `description` alaninda `\n` escape'i doublecoded olabiliyor (stored value'da `\n` literal gorunur). Cozum: **tek paragraf**, gercek satir sonu yerine cumleler arasi bosluk. Cok satir gerekirse `contentFormat: adf` ile explicit ADF paragraph block kullan.
- **`fields` parametresi ayiklama:** `editJiraIssue`'de description verirken `{"description": "..."}` formatinda JSON object gonderilir. `createJiraIssue`'de ise `description` top-level parametredir. Karistirma.
- **Duplicate yaratma:** Yeni ticket acmadan once `searchJiraIssuesUsingJql` ile benzer summary ara. 2026-04 audit'inde MEK-152..166 ve MEK-168..169 duplicate olarak bulundu ve archive edildi.
- **Parent tutarsizligi:** Story/Görev olusturulurken parent Epic `createJiraIssue` cagrisinda `parent` field'iyle ayarlanir. Sonradan `editJiraIssue` ile parent degistirmek karmasiktir.
- **Archive edilmis ticket'lar (2026-04-22 itibariyla, `Tamam` statusu ama kapsam gercekten tamamlanmis degil):** MEK-18..29 (12 bos Epic, duplicate), MEK-152, 154, 156, 158, 160, 162, 164, 166, 168, 169 (10 duplicate). Bunlar referans amacli Jira'da durur; yeni baslangic yaparken dikkat.

## Session baslangicinda yapilacaklar

Her Claude Code oturumunda Jira'yla etkilesmeye baslarken:
1. `getAccessibleAtlassianResources` ile cloudId'yi dogrula.
2. Oturumda ne yapilacaksa once ilgili MEK-NNN'i bul, status'u gor.
3. Yeni is varsa once architecture + bu dosya uzerinden uygun Epic'e bagla.

## Worklog (zaman kaydi)

Her ticket uzerinde gecirilen zaman Jira'ya **worklog** olarak islenir. Bu yontem delivery manager ve musteri raporlama icin gerekli; agent'lar da takip edebilmek icin kullanir.

### Format
`addWorklogToJiraIssue` parametreleri:
- `issueIdOrKey`: Ornegin `"MEK-190"`
- `timeSpent`: `"2h"` / `"30m"` / `"1d"` / `"45m"` / `"1d 4h"` — kisa gosterim
- `started`: ISO 8601, ornek `"2026-04-22T09:00:00.000+0300"` (atlanirsa simdiki zamana yazilir)
- `commentBody`: Kisa Turkce aciklama — ne yapildi
- `contentFormat`: `"markdown"` tercih edilir

### Ne zaman log eklenir
| Durum | Kural |
|-------|-------|
| Tek oturumda biten kucuk is (< 1 saat) | Isin sonunda tek worklog |
| Ayni ticket'a birden fazla oturum | Her oturum sonunda ayri worklog |
| Uzun surecek is (multi-day) | Her gun sonu worklog (pomodoro tarzi mantikli takip) |
| Blocker / arastirma / kod harici calisma | Ayri worklog + `commentBody`'de `[arastirma]` / `[blocked]` isaretiyle |
| Review, QA, bugfix dongusu | Her donguye ayri worklog |

### Ornek
```json
{
  "issueIdOrKey": "MEK-190",
  "timeSpent": "3h",
  "started": "2026-04-22T10:00:00.000+0300",
  "commentBody": "Advisory lock + (chat_id, chat_seq) unique index eklendi. Property test 10000 iter temiz.",
  "contentFormat": "markdown"
}
```

### Iyi worklog mesajinin ozellikleri
- **Spesifik:** "Mesaj gonderme calisildi" degil, "Advisory lock implementasyonu + unit test"
- **Sonucu bildirir:** "Tamamlandi", "Blocker: X", "Kismen tamam, Y kaldi"
- **Turkce:** kisa, teknik detay parantez icinde
- **Sure gercekci:** 15m granulaste kaydedilir, 5 saat araliksiz calisma naddir

### Agent akisi — worklog entegrasyonu
1. **Ise baslarken:** saati not et (baslangic)
2. **Calisma sirasinda:** `addCommentToJiraIssue` ile blocker notu eklenebilir (worklog'a ek olarak)
3. **Is bittiginde (veya oturum sonu):**
   - `addWorklogToJiraIssue` ile toplam sureyi gir
   - Status transition yap (Devam Ediyor veya Tamam)
   - Commit mesaji at

### Oturum uzerinden raporlama

Uzun surecek (multi-day) isin gunluk worklog'u, haftalik delivery raporu icin:
- `searchJiraIssuesUsingJql` ile `project = MEK AND assignee = currentUser() AND updated > -7d`
- Worklog toplam sureleri JQL `worklogAuthor = currentUser() AND worklogDate > -7d` ile cikar
- `atlassian:generate-status-report` skill'i haftalik ozet icin kullanilabilir

### Sure tahmin vs gercek

| Alan | Kullanim |
|------|----------|
| `originalEstimate` (Jira custom field) | Ticket acilirken tahmin — opsiyonel |
| `timeSpent` (worklog toplami) | Gerceklesen sure |
| `remainingEstimate` | Kalan tahmin (agent guncelleyebilir) |

MVP'de zorunlu degil — sadece `timeSpent` (worklog) yeterli. Estimation ekibi buyurse ileride eklenir.

## Sorumlu

Jira konfigurasyonu ve Epic hiyerarsisini **Kutay Erdogan** yonetir. Scope degisimi, yeni Epic, tier policy degismesi gibi kararlar `CONSTITUTION.md > Mimari kararlar` tablosuna islenir ve bu dosyadaki Epic haritasi guncellenir.

## Iliskili dokumanlar

- **Git workflow:** `.docs/GIT.md` — branch, commit, PR, merge standardi (Jira ticket ile nasil eslenir)
- **Calisma akisi:** `.docs/WORKFLOW.md`
- **Agent erisim matrisi:** `.docs/AGENTS.md`
- **Gunluk kilavuz:** `DEVELOPMENT-GUIDE.md`
