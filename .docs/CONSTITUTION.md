# CONSTITUTION (Template)

_Olusturulma: [YYYY-MM-DD] | Son guncelleme: [YYYY-MM-DD]_

## Proje ozeti
- **Proje adi:** [PROJE_ADI]
- **Musteri:** [MUSTERI_ADI]
- **Kisa amac:** [1-2 cumle]

## Teknik stack
### Backend
- Runtime: [.NET 8 / baska]
- Mimari: [Clean Architecture / baska]
- ORM: [EF Core / Dapper / baska]

### Frontend
- Framework: [Angular / React / baska]
- State: [signals / redux / baska]
- UI kutuphanesi: [opsiyonel]

### Mobile (opsiyonel)
- Framework: [React Native / native / yok]

### Altyapi
- Veritabani: [MSSQL / PostgreSQL / baska]
- Deployment: [IIS / K8s / baska]
- CI/CD: [Azure DevOps / GitHub Actions / baska]

## Kod ve mimari kurallari
- Katman sinirlari korunur (domain, application, infrastructure, API, UI)
- API key/secret degerleri kaynak koda yazilmaz
- Public API kontratlari acik sekilde dokumante edilir
- Turkce karakter destegi (UTF-8, siralama/arama) dogrulanir

## Guvenlik kurallari
- Kimlik dogrulama ve yetkilendirme modeli: [JWT/SSO/...]
- Hassas veriler icin sifreleme stratejisi: [at rest / in transit]
- Input validation tum giris noktalarinda zorunludur

## Hata yonetimi
- Global exception handling zorunlu
- Standart hata cevabi formati tanimlanir
- Teknik hata detayi son kullaniciya acik edilmez

## Mimari kararlar
| Tarih | Karar | Gerekce |
|-------|-------|---------|
| [YYYY-MM-DD] | Template olusturuldu | Baslangic |

## Musteri kisitlari
- [Varsa buraya ekleyin]

## Acik sorular
- [ ] [Soru 1]
- [ ] [Soru 2]

## Figma referansi (opsiyonel)
- Figma URL: [YOK / URL]
