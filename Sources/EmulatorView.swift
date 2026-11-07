import SwiftUI
import WebKit

// WKWebView 封装，加载本地 emulator/index.html 并注入 ROM
struct EmulatorWebView: UIViewRepresentable {
    let game: Game
    let romData: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(game: game, romData: romData)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let contentController = WKUserContentController()
        // 原生桥：页面就绪时通知，并回传游戏名
        contentController.add(context.coordinator, name: "ready")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.13, alpha: 1)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // 加载本地 index.html（emulator 目录，可访问相对 js/css）
        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html",
                                         subdirectory: "emulator") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // 停止音频/循环
        webView.evaluateJavaScript("window.nesPause && window.nesPause()", completionHandler: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let game: Game
        let romData: Data?
        weak var webView: WKWebView?
        private var injected = false

        init(game: Game, romData: Data?) {
            self.game = game
            self.romData = romData
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 注入 ROM（页面 jsnes 已加载）
            injectRomIfNeeded()
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "ready" {
                injectRomIfNeeded()
            }
        }

        private func injectRomIfNeeded() {
            guard !injected, let data = romData else { return }
            injected = true
            let b64 = data.base64EncodedString()
            let name = game.name
            let js = "window.loadRom && window.loadRom('\(b64)', '\(name)');"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

// 模拟器页面：全屏 WKWebView
struct EmulatorView: View {
    let game: Game
    let romData: Data?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.13)
                .ignoresSafeArea()
            EmulatorWebView(game: game, romData: romData)
                .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(false)
    }
}
