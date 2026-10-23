# Translate Desktop

Mac-приложение для сайта Google Переводчика: Swift + AppKit + WebKit, без Xcode-проекта, устроено как
Maps Desktop (`~/Developer/MapsDesktop`), только проще. Неофициальное — в имени и иконке нет слова и
логотипа Google, «for Google Translate» только в описаниях.

## Сборка и релиз

- `./build.sh [--install] [--zip]` — универсальная сборка (arm64 + x86_64) в `build/Translate Desktop.app`,
  нужны только Command Line Tools. Переменные: `VERSION`, `BUILD`, `SIGN_ID`.
- Подпись — сертификатом «Maps Desktop Developer» из `~/Developer/MapsDesktop-keys/signing.keychain-db`
  (пароль в `signing_keychain_password.txt`), если он есть, иначе ad-hoc.
- Релиз: `git tag vX.Y.Z && git push origin vX.Y.Z` — GitHub Actions (`.github/workflows/release.yml`)
  подписывает сертификатом «Maps Desktop Developer», кладет `TranslateDesktop.zip` и `TranslateDesktop.zip.sig`.
  Приложения обновляются сами (`Sources/Updater.swift`, тот же, что в Maps Desktop). Тег выпускать только
  по команде владельца.
- Секреты репозитория: `MAPSDESKTOP_CERT_P12`, `MAPSDESKTOP_CERT_PASSWORD` (те же, что у Maps Desktop) и
  `TRANSLATEDESKTOP_UPDATE_KEY` — вводит владелец сам.
- Ключ обновлений свой: `~/Developer/MapsDesktop-keys/translate_update_key.txt` (публичная половина — в
  `Info.plist`, `NMUpdatePublicKey`). Ключи в репозиторий не класть.
- После релиза проверять: скачать, `swift tools/update_key.swift verify …`, `codesign -dvv`, версия.
- Расширения для Chrome и перехвата ссылок нет — только если владелец попросит.
- GitHub с этого Мака открывается только с включенным VPN; `git push`/`gh` запускать вне песочницы.

## Как устроено

- `Sources/TranslateWindow.swift` — окно с WKWebView: Переводчик, вход в аккаунт и согласие на cookies —
  в окне, остальные ссылки — в браузер по умолчанию; сайту представляемся Chrome. Скачивания — в
  «Загрузки», микрофон — только самому Переводчику.
- `Sources/Theme.swift` — темная тема своя у Переводчика, но системную тему сайт в WebKit не подхватывает
  (`prefers-color-scheme` он не читает). В шапке сайта кнопка «светлая/темная» (`[jsname=jerT5]`), выбор
  Google хранит у себя (у вошедших — в аккаунте). Приложение после загрузки и при смене оформления
  сравнивает цвет фона страницы с нужной темой и, если не совпало, нажимает эту кнопку. Если Google
  переименует кнопку — чинить селектор там.
- Меню «Оформление»: Авто / Светлая / Темная (`theme` в настройках приложения).
- Перевод документов: «Download translation» работает (blob из iframe → WKDownload). «Open translation»
  открывает пустое окно, которое страница заполняет сама, — такие окна приложение не открывает.

## Отладка без доступа к экрану

`tools/shot.sh имя ['js']` — выполнить скрипт в странице запущенного приложения и сохранить снимок
`build/имя.png`, адрес и результат скрипта — в `build/имя.png.txt`.

## Тексты

Интерфейс на языке системы: ключи — английский текст, переводы в `Resources/*.lproj`.
В русских текстах не использовать букву «ё».
