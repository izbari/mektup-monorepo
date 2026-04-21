# Proje Template - Agent Calisma Kilavuzu

## Proje kimligi
- **Proje adi:** [PROJE_ADI]
- **Musteri:** [MUSTERI_ADI]
- **Olusturulma tarihi:** [YYYY-MM-DD]
- **Takim lideri:** [AD_SOYAD]
- **Prompt engineer:** [AD_SOYAD]

## Oturum baslangicinda okunacaklar
1. `.docs/project-init/` (varsa)
2. `.docs/CONSTITUTION.md`
3. `.docs/AGENTS.md`
4. `.docs/WORKFLOW.md`
5. En son `.docs/meetings/MEETING-*.md` (varsa)
6. `.specify/specs/` altindaki aktif spec dosyalari

## Ornek teknoloji stack'i (gerektiginde guncelle)
- Frontend: Angular (LTS)
- Backend: .NET 8
- Veritabani: MSSQL
- Deployment: Windows Server / IIS
- CI/CD: Azure DevOps Pipelines

## Standart akis
1. Toplanti/transkript bilgilerini isle, `MEETING-NNN.md` olustur
2. `speckit.specify`
3. `speckit.clarify`
4. `speckit.plan`
5. `speckit.analyze`
6. `speckit.tasks`
7. Implementasyon
8. UI/UX kontrol (varsa)
9. Kod inceleme
10. QA

## Ortak kurallar
- API key/secret degerleri kaynak koda yazilmaz
- Turkce karakter uyumlulugu test edilir
- Mimari kararlar `.docs/CONSTITUTION.md` icinde kayit altina alinir
- Surec kurallari `.docs/WORKFLOW.md` icinde tutulur

## Not
Bu dosya template amacli sadeleştirilmistir. Yeni proje baslangicinda koseli parantezli alanlari doldurun.
