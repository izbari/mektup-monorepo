# Claude Agentic Template Repository

Bu repository, kurumsal projelerde tekrar kullanilabilir bir **Claude agentic baslangic iskeleti** olarak hazirlanmistir.

## Hedef Yapi
- `src/backend`: Backend uygulama kaynaklari
- `src/frontend`: Web uygulama kaynaklari
- `src/mobile`: Mobile uygulama kaynaklari
- `.docs`: Proje anayasa/surec dokumanlari
- `.specify`: Spec ve planlama dosyalari
- `.claude`: Agent kurallari, roller ve skill dosyalari

## Toplu Temizleme (Brand/Key Sanitization)

Template dagitimindan once kimlik, marka, kurum, ortam URL ve API key izlerini temizlemek icin hazir script kullanin:

```bash
chmod +x scripts/sanitize-template.sh
./scripts/sanitize-template.sh
```

## Notlar
- Gercek secret/config dosyalari (`google-services.json`, `GoogleService-Info.plist`, log dosyalari) template repoda tutulmamalidir.
- Template olarak dagitmadan once kendi kurum bilgilerinizi `CONSTITUTION`, `WORKFLOW`, `AGENTS` dokumanlarina isleyin.
