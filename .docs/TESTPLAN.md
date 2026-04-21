# Test Planı

## Test seviyeleri

### Unit testler
- Backend: xUnit ile her service method test edilmeli
- Frontend: Jest ile her component ve service test edilmeli
- Minimum coverage: %70

### Integration testler
- API endpoint'leri end-to-end test edilmeli
- Veritabanı işlemleri in-memory DB ile test edilmeli

### UAT (Kullanıcı kabul testleri)
- Her feature için müşteri onaylı senaryo listesi
- Staging ortamında müşteriyle birlikte yapılır

## Kabul kriterleri
Her feature tamamlanmış sayılmak için:
- [ ] Unit testler yazıldı ve geçiyor
- [ ] Integration testler yazıldı ve geçiyor
- [ ] Review-agent uyumsuzluk raporu temiz
- [ ] Prompt engineer merge kararını verdi
- [ ] UAT senaryoları müşteri tarafından onaylandı

## Test senaryoları

_Spec tamamlandıkça buraya eklenir._

### Şablon
```
#### TC-NNN — Senaryo adı
- **İlgili spec:** specs/NNN-feature/spec.md
- **Ön koşul:** ...
- **Adımlar:** 
  1. ...
  2. ...
- **Beklenen sonuç:** ...
- **Durum:** Yazılmadı / Geçti / Başarısız
```
