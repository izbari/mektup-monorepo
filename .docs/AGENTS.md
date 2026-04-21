# Agent Rolleri ve Erisim Haritasi (Template)

## Genel kurallar
- Agentlar `CONSTITUTION.md` kararlarina uyar
- API key/secret kaynak koda yazilmaz
- Alan disi degisiklik yapilmaz

## Ornek erisim matrisi
| Agent | Yazma erisimi | Okuma erisimi |
|-------|----------------|---------------|
| project-manager | dokumanlar | tum proje |
| solution-architect | `.docs/**`, `.specify/**` | tum proje |
| backend-agent | `src/backend/**` | `.docs/**`, `.specify/**` |
| frontend-agent | `src/frontend/**` | `.docs/**`, `.specify/**` |
| mobile-agent | `src/mobile/**` | `.docs/**`, `.specify/**` |
| review-agent | yok (read-only) | tum proje |
| qa-engineer | yok (read-only) | tum proje |

## Cross-agent kurallari
- API kontrat degisikligi oldugunda ilgili tum katmanlar bilgilendirilir
- Mimari karar degisikligi gerektiren islerde solution-architect review'a dahil edilir
