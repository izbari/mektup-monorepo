# Gelistirme Kilavuzu (Template)

Bu dokuman yeni bir projeyi bu repository sablonu ile baslatmak icin hazirlanmistir.

## 1) Baslangic
- `CLAUDE.md` icindeki proje kimligi alanlarini doldurun
- `.docs/CONSTITUTION.md` dosyasini projeye gore guncelleyin
- `.docs/AGENTS.md` ve `.docs/WORKFLOW.md` dosyalarini ekip isleyisine gore netlestirin

## 2) Analiz ve plan
1. Toplanti notlari/transkriptlerinden `MEETING-NNN.md` olusturun
2. `specify` ile spec taslagi cikarin
3. `clarify` ile belirsizlikleri kapatin
4. `plan` ile teknik yaklasimi netlestirin
5. `analyze` ile tutarlilik kontrolu yapin
6. `tasks` ile is dagilimini olusturun

## 3) Gelistirme
- Isleri ilgili alanlara ayirin (backend/frontend/mobile)
- Her degisiklikte:
  - mimari karar gerekiyorsa `CONSTITUTION.md` guncelleyin
  - degisiklik talebini gerekiyorsa `CHANGES.md`'ye kaydedin
  - regresyon risklerini not alin

## 4) Kapatma
- Kod inceleme
- QA kontrolu
- Gerekirse dokumantasyon guncellemesi

## Template notu
Bu dosya projeye ozel referanslardan arindirilmistir. Ornekler ve komut isimleri ekip standardina gore uyarlanabilir.
