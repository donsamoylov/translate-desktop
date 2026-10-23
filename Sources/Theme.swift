import Foundation

/// Оформление из меню: «Авто» — как в системе (по умолчанию), или всегда светлое / темное.
enum Theme: String {
    case system, light, dark

    static var current: Theme {
        get { Theme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "theme") }
    }
}

/// Темная тема — своя у Google Переводчика: в шапке сайта кнопка «светлая/темная», выбор Google помнит
/// сам. Системную тему сайт в WebKit не подхватывает, поэтому, если страница не в той теме, приложение
/// нажимает эту кнопку. Тему страницы узнаем по цвету фона, а не по служебным классам Google.
enum SiteTheme {
    /// Выполняется через callAsyncJavaScript с аргументом `dark`, в своем мире скриптов.
    static let script = """
        window.tdWantDark = dark;
        if (window.tdBusy) return;            // уже идет — подхватит новое значение
        window.tdBusy = true;
        const sleep = ms => new Promise(done => setTimeout(done, ms));
        const darkBackground = el => {
          const c = getComputedStyle(el).backgroundColor.match(/[\\d.]+/g)?.map(Number) ?? [];
          return c.length < 3 || c[3] === 0 ? null : c[0] + c[1] + c[2] < 384;
        };
        const siteIsDark = () => darkBackground(document.body) ?? darkBackground(document.documentElement) ?? false;
        try {
          // Кнопка появляется, когда сайт дорисуется; ждем до 20 секунд.
          for (let i = 0, clicks = 0; i < 80 && clicks < 3; i++) {
            const button = document.body && document.querySelector('[jsname=jerT5]');
            if (!button) { await sleep(250); continue; }
            if (siteIsDark() === window.tdWantDark) return;
            button.click();
            clicks++;
            for (let j = 0; j < 20 && siteIsDark() !== window.tdWantDark; j++) await sleep(100);
          }
        } finally {
          window.tdBusy = false;
        }
        """
}
