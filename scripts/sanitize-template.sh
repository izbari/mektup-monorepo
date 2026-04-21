#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[1/5] Removing project-specific secret/config artifacts..."
rm -f src/mobile/android/app/src/prod/google-services.json
rm -f src/mobile/android/app/src/staging/google-services.json
rm -f src/mobile/ios/GoogleService-Info.plist
rm -f src/mobile/ios/Firebase/Prod/GoogleService-Info.plist
rm -f src/mobile/ios/Firebase/Staging/GoogleService-Info.plist
rm -f src/mobile/xcode-build.log src/mobile/xcode-build-after-fix.log src/mobile/xcode-export.log
rm -f src/mobile/temp_b64.txt src/mobile/temp_base64.txt

echo "[2/5] Removing project-specific build leftovers..."
rm -f src/mobile/android/app/google-services.json
rm -f src/mobile/ios/gurselRouteApp\ copy-Info.plist

echo "[3/5] Replacing brand/company identifiers in text files..."
TEXT_FILES="$(rg -l \
  --glob '!**/node_modules/**' \
  --glob '!**/dist/**' \
  --glob '!**/build/**' \
  --glob '!**/bin/**' \
  --glob '!**/obj/**' \
  --glob '!**/*.png' \
  --glob '!**/*.jpg' \
  --glob '!**/*.jpeg' \
  --glob '!**/*.gif' \
  --glob '!**/*.webp' \
  --glob '!**/*.ico' \
  --glob '!**/*.pdf' \
  --glob '!**/*.zip' \
  --glob '!**/*.jar' \
  --glob '!**/*.dll' \
  --glob '!**/*.so' \
  --glob '!**/*.a' \
  --glob '!**/*.dylib' \
  --glob '!**/*.woff' \
  --glob '!**/*.woff2' \
  --glob '!**/*.ttf' \
  --glob '!**/*.eot' \
  '(Gürsel|GURSEL|gursel|Gursel|gürsel|RotaOptimizasyon|Rota Optimizasyon|caretta\.net|gurseltur|com\.gurselapp)' \
  src .docs .specify .claude CLAUDE.md DEVELOPMENT-GUIDE.md 2>/dev/null || true)"

if [[ -n "${TEXT_FILES}" ]]; then
  while IFS= read -r file; do
    perl -0777 -i -pe '
      s/Gürsel/TemplateCo/g;
      s/GURSEL/TEMPLATECO/g;
      s/gürsel/templateco/g;
      s/Gursel/Template/g;
      s/gursel/template/g;
      s/Rota Optimizasyon/Agentic Template/g;
      s/RotaOptimizasyon/AgenticTemplate/g;
      s/caretta\.net/example\.com/g;
      s/gurseltur/examplecorp/g;
      s/com\.gurselapp/com\.templateapp/g;
    ' "$file"
  done <<< "$TEXT_FILES"
fi

echo "[4/5] Scrubbing obvious hardcoded keys/URLs in env/config files..."
ENV_FILES="$(rg -l \
  --glob 'src/frontend/src/environments/*.ts' \
  --glob 'src/mobile/**' \
  '(AIza[0-9A-Za-z\-_]{20,}|https://[A-Za-z0-9._-]+|clientId\s*:\s*["'\''][^"'\'']+["'\''])' \
  2>/dev/null || true)"

if [[ -n "${ENV_FILES}" ]]; then
  while IFS= read -r file; do
    perl -0777 -i -pe '
      s#AIza[0-9A-Za-z\-_]{20,}#REPLACE_WITH_GOOGLE_MAPS_API_KEY#g;
      s#https://goapi\.examplecorp\.com\.tr/#https://api.example.com/#g;
      s#https://aiapi\.examplecorp\.com\.tr/#https://api.example.com/#g;
      s#https://templateapi\.example\.com/#https://api.example.com/#g;
      s#https://api\.example\.com/api/#https://api.example.com/v1/#g;
      s/clientId:\s*["'\''][^"'\'']+["'\'']/clientId: "REPLACE_WITH_AAD_CLIENT_ID"/g;
      s#https://login\.microsoftonline\.com/[A-Za-z0-9-]+#https://login.microsoftonline.com/REPLACE_WITH_TENANT_ID#g;
    ' "$file"
  done <<< "$ENV_FILES"
fi

echo "[5/5] Done. Run this to verify leftovers:"
echo "rg -n '(Gürsel|gursel|Gursel|RotaOptimizasyon|caretta\\.net|gurseltur|AIza|com\\.gurselapp)' src .docs .specify .claude"
