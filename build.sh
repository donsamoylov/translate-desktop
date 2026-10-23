#!/bin/zsh
# Сборка Translate Desktop. Нужны только Command Line Tools (или Xcode).
#   ./build.sh                 — собрать build/Translate Desktop.app
#   ./build.sh --install       — и поставить в ~/Applications
#   ./build.sh --zip           — и упаковать build/TranslateDesktop.zip для релиза
# Переменные: VERSION (1.2.0; у сборки 0.0.0 нет автопроверки обновлений), BUILD (номер сборки),
# SIGN_ID (имя сертификата подписи; по умолчанию — сертификат Maps Desktop из
# ~/Developer/MapsDesktop-keys/signing.keychain-db, если он есть, иначе ad-hoc).
set -euo pipefail
cd "${0:A:h}"
VERSION=${VERSION:-0.0.0}
BUILD=${BUILD:-0}
APP="build/Translate Desktop.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset

# Универсальная сборка: Apple Silicon и Intel.
for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos14 -framework AppKit -framework WebKit \
    Sources/*.swift -o build/TranslateDesktop-$arch
done
lipo -create build/TranslateDesktop-arm64 build/TranslateDesktop-x86_64 -output "$APP/Contents/MacOS/TranslateDesktop"
rm build/TranslateDesktop-arm64 build/TranslateDesktop-x86_64

swift make_icon.swift build/AppIcon.iconset >/dev/null
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
sed "s/__VERSION__/$VERSION/; s/__BUILD__/$BUILD/" Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

# Подпись постоянным сертификатом: с ним macOS после пересборки и обновления считает приложение тем же
# и помнит разрешения (микрофон). Сертификат — тот же, что у Maps Desktop: локально — из отдельного
# keychain рядом с его ключами (в список keychain системы он не добавлен), в релизах — из секретов GitHub.
KEYS=~/Developer/MapsDesktop-keys
SIGN_ARGS=()
if [[ -z ${SIGN_ID:-} && -f $KEYS/signing.keychain-db ]]; then
  security unlock-keychain -p "$(cat $KEYS/signing_keychain_password.txt)" $KEYS/signing.keychain-db
  SIGN_ID="Maps Desktop Developer"
  SIGN_ARGS=(--keychain $KEYS/signing.keychain-db)
fi
codesign --force --timestamp=none "${SIGN_ARGS[@]}" --sign "${SIGN_ID:--}" "$APP"
codesign --verify --strict "$APP"

for arg in "$@"; do
  case $arg in
    --install)
      rm -rf ~/Applications/"Translate Desktop.app"
      cp -R "$APP" ~/Applications/
      $LSREGISTER -f ~/Applications/"Translate Desktop.app"
      echo "Установлено: ~/Applications/Translate Desktop.app"
      ;;
    --zip)
      ditto -c -k --keepParent "$APP" build/TranslateDesktop.zip
      echo "Архив: build/TranslateDesktop.zip"
      ;;
  esac
done
