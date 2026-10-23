#!/bin/zsh
# Отладка без доступа к экрану: выполнить скрипт в странице запущенного приложения и сохранить снимок.
# tools/shot.sh имя ['js'] → build/имя.png и build/имя.png.txt (адрес страницы и результат скрипта)
cd "${0:A:h}/.."
S=$PWD/build/$1.png; rm -f $S $S.txt
defaults write io.github.donsamoylov.translatedesktop DebugSnapshot -string $S
defaults write io.github.donsamoylov.translatedesktop DebugEval -string "${2:-''}"
swift -e "import Foundation; DistributedNotificationCenter.default().postNotificationName(.init(\"io.github.donsamoylov.translatedesktop.snapshot\"), object: nil, userInfo: nil, deliverImmediately: true)"
for i in $(seq 20); do [ -f $S ] && break; sleep 0.5; done
defaults delete io.github.donsamoylov.translatedesktop DebugEval
defaults delete io.github.donsamoylov.translatedesktop DebugSnapshot
cat $S.txt 2>/dev/null || echo "нет снимка — приложение не запущено?"
