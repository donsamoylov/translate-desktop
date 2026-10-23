import AppKit
import WebKit

final class TranslateWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    static let home = URL(string: "https://translate.google.com/")!

    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()        // вход в аккаунт и настройки сохраняются
        config.preferences.isElementFullscreenEnabled = true
        config.userContentController.addUserScript(Site.style)
        // Представляемся Safari той версии, что стоит на Маке: движок у нас тот же. Если называться Chrome,
        // Google замечает несовпадение и не пускает в аккаунт («This browser or app may not be secure»),
        // а без слова Safari принимает окно за встроенный браузер.
        let safari = Bundle(path: "/Applications/Safari.app")?.infoDictionary?["CFBundleShortVersionString"] as? String
        config.applicationNameForUserAgent = "Version/\(safari ?? "26.0") Safari/605.1.15"
        webView = WKWebView(frame: .zero, configuration: config)
        // Пока страница грузится, WebKit заливает окно белым — в темной теме это вспышка. Свой фон не
        // рисуем: под страницей виден фон окна.
        webView.setValue(false, forKey: "drawsBackground")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Translate Desktop"
        // Заголовок окна в цвет шапки Переводчика: белая, в темной теме — rgb(19, 19, 20).
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(srgbRed: 19 / 255, green: 19 / 255, blue: 20 / 255, alpha: 1)
                : .white
        }
        window.minSize = NSSize(width: 480, height: 360)
        window.contentView = webView
        window.center()
        window.setFrameAutosaveName("TranslateWindow")
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        super.init(window: window)
        window.delegate = self               // контроллер — в цепочке ответчиков: ему идут команды меню
        webView.navigationDelegate = self
        webView.uiDelegate = self
        applyTheme()
        appearanceObservation = window.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.syncSiteTheme() }
        }
        // KVO срабатывает не всегда, поэтому слушаем и системное уведомление о смене оформления.
        // Вид окна обновляется чуть позже уведомления — проверяем с задержкой.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.syncSiteTheme() }
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(saveSnapshot),
            name: Notification.Name("io.github.donsamoylov.translatedesktop.snapshot"), object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var appearanceObservation: NSKeyValueObservation?

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    /// Тема из меню: «Авто» следует за macOS, иначе окно получает свой вид, а сайт — ту же тему.
    func applyTheme() {
        switch Theme.current {
        case .system: window?.appearance = nil
        case .light: window?.appearance = NSAppearance(named: .aqua)
        case .dark: window?.appearance = NSAppearance(named: .darkAqua)
        }
        syncSiteTheme()
    }

    private func syncSiteTheme() {
        guard let url = webView.url, Site.isTranslate(url) else { return }
        let dark = window?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        webView.callAsyncJavaScript(SiteTheme.script, arguments: ["dark": dark], in: nil, in: .defaultClient)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        syncSiteTheme()
    }

    /// Прозрачный фон — только у самого Переводчика. Страницы входа и согласия на cookies рассчитаны на
    /// белый фон: без него их темный текст ложится на темное окно.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        let onTranslate = webView.url.map(Site.isTranslate) ?? false
        webView.setValue(!onTranslate, forKey: "drawsBackground")
    }

    // MARK: Навигация: Переводчик и вход Google — в окне, остальное — в браузер

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.shouldPerformDownload { return decisionHandler(.download) }
        guard let url = action.request.url, let scheme = url.scheme?.lowercased() else {
            return decisionHandler(.allow)
        }
        if ["about", "blob", "data", "javascript"].contains(scheme) { return decisionHandler(.allow) }
        if scheme != "http" && scheme != "https" {
            NSWorkspace.shared.open(url)            // mailto: и т.п.
            return decisionHandler(.cancel)
        }
        guard action.targetFrame?.isMainFrame ?? true else { return decisionHandler(.allow) }

        // Переходы без клика (переадресация при входе, согласие на cookies) по Google — тоже в окне.
        let clicked = action.navigationType == .linkActivated
        if Site.isTranslate(url) || Site.isSignIn(url) || (!clicked && Site.isGoogle(url)) {
            return decisionHandler(.allow)
        }
        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
    }

    /// target=_blank и window.open: Переводчик — сюда же, остальное — в браузер.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url, url.absoluteString != "about:blank" else { return nil }
        if Site.isTranslate(url) { load(url) } else { NSWorkspace.shared.open(url) }
        return nil
    }

    // MARK: Файлы: выбор картинки или документа для перевода, скачивание перевода

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.beginSheetModal(for: window!) { completionHandler($0 == .OK ? panel.urls : nil) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    /// Как в браузере: в «Загрузки», при совпадении имени — «имя 2.pdf».
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let name = suggestedFilename as NSString
        var url = folder.appendingPathComponent(suggestedFilename)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            let numbered = "\(name.deletingPathExtension) \(n)"
            url = folder.appendingPathComponent(name.pathExtension.isEmpty ? numbered : "\(numbered).\(name.pathExtension)")
            n += 1
        }
        downloads[ObjectIdentifier(download)] = url
        completionHandler(url)
    }

    private var downloads: [ObjectIdentifier: URL] = [:]

    /// Как Safari: стопка «Загрузки» в Dock подпрыгивает.
    func downloadDidFinish(_ download: WKDownload) {
        if let url = downloads.removeValue(forKey: ObjectIdentifier(download)) {
            DistributedNotificationCenter.default().post(name: Notification.Name("com.apple.DownloadFileFinished"),
                                                         object: url.resolvingSymlinksInPath().path)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloads.removeValue(forKey: ObjectIdentifier(download))
        NSAlert(error: error).beginSheetModal(for: window!)
    }

    // MARK: Микрофон для голосового ввода — только самому Переводчику; macOS спросит разрешение сама

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(type == .microphone && Site.isTranslateHost(origin.host) ? .grant : .deny)
    }

    // MARK: Окна JavaScript

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.beginSheetModal(for: window!) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: L("Cancel"))
        alert.beginSheetModal(for: window!) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    // MARK: Команды меню

    @objc func reload(_ sender: Any?) { webView.reload() }
    @objc func zoomIn(_ sender: Any?) { webView.pageZoom = min(3, webView.pageZoom + 0.1) }
    @objc func zoomOut(_ sender: Any?) { webView.pageZoom = max(0.5, webView.pageZoom - 0.1) }
    @objc func actualSize(_ sender: Any?) { webView.pageZoom = 1 }

    // Отладка без доступа к экрану (tools/shot.sh): по уведомлению выполнить скрипт из DebugEval и
    // сохранить снимок страницы в DebugSnapshot, а адрес и результат скрипта — рядом, в .txt.
    @objc private func saveSnapshot() {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: "DebugSnapshot") else { return }
        webView.evaluateJavaScript(defaults.string(forKey: "DebugEval") ?? "''") { result, error in
            let text = "\(self.webView.url?.absoluteString ?? "")\n\(result ?? error.map { "\($0)" } ?? "")"
            try? text.write(toFile: path + ".txt", atomically: true, encoding: .utf8)
            self.webView.takeSnapshot(with: nil) { image, _ in
                guard let tiff = image?.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
                try? png.write(to: URL(fileURLWithPath: path))
            }
        }
    }
}

/// Какие адреса открываются в окне.
enum Site {
    /// google.com, google.de, google.co.uk, google.com.au…
    private static let google = #"google\.(com|[a-z]{2})(\.[a-z]{2})?$"#

    static func isTranslate(_ url: URL) -> Bool { isTranslateHost(url.host ?? "") }

    static func isTranslateHost(_ host: String) -> Bool { matches(host, #"^translate\."# + google) }

    /// Вход в аккаунт и согласие на cookies — в окне, даже по клику.
    static func isSignIn(_ url: URL) -> Bool {
        let host = url.host ?? ""
        return matches(host, #"^(accounts|consent)\."# + google) || host.lowercased() == "accounts.youtube.com"
    }

    static func isGoogle(_ url: URL) -> Bool { matches(url.host ?? "", #"(^|\.)"# + google) }

    /// Кнопка «Приложения Google» и всплывающие подсказки панели Google (реклама Chrome и т.п.) ведут в
    /// другие сервисы — в окне Переводчика они не нужны. Прячутся вместе с обертками, в которых они одни,
    /// чтобы не осталось пустого места.
    static let style = WKUserScript(source: """
        if (/^translate\\.google\\./.test(location.hostname)) {
          const hide = ['a[href*="/about/products"]', 'iframe[name="callout"]'].map(t =>
            `${t}, :has(> ${t}:only-child), :has(> :only-child > ${t}:only-child),
             :has(> :only-child > :only-child > ${t}:only-child)`);
          const style = document.createElement('style');
          style.textContent = `${hide.join(',')} { display: none !important; }`;
          document.documentElement.appendChild(style);
        }
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true)

    private static func matches(_ host: String, _ pattern: String) -> Bool {
        host.lowercased().range(of: pattern, options: .regularExpression) != nil
    }
}
