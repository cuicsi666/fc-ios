import SwiftUI
import WebKit
import UIKit
import AudioToolbox

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
        // 原生桥：触觉反馈（按钮/摇杆按下时 JS 调用）
        contentController.add(context.coordinator, name: "haptic")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.13, alpha: 1)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // 加载本地 index.html（兼容 Resources 目录打包与 bundle 根两种布局）
        let subs = ["Resources/emulator", "emulator"]
        var loaded = false
        for sub in subs {
            if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html",
                                             subdirectory: sub) {
                webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
                loaded = true
                break
            }
        }
        if !loaded, let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") {
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

        // 强震动生成器（heavy 风格，最大强度）
        private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)

        init(game: Game, romData: Data?) {
            self.game = game
            self.romData = romData
            super.init()
            heavyGenerator.prepare()
            rigidGenerator.prepare()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 注入 ROM（页面 jsnes 已加载）
            injectRomIfNeeded()
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "ready" {
                injectRomIfNeeded()
            } else if message.name == "haptic" {
                triggerHaptic(message.body)
            }
        }

        // 超强震动：heavy + rigid 连击，最大强度
        private func triggerHaptic(_ body: Any) {
            let type = body as? String ?? "press"
            // 使用系统振动（最强）+ Taptic Engine 连击
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

            if #available(iOS 13.0, *) {
                heavyGenerator.impactOccurred(intensity: 1.0)
                rigidGenerator.impactOccurred(intensity: 1.0)
                // 二次连击增强体感
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.heavyGenerator.impactOccurred(intensity: 1.0)
                    self.rigidGenerator.impactOccurred(intensity: 1.0)
                }
            } else {
                heavyGenerator.impactOccurred()
            }
        }

        private func injectRomIfNeeded() {
            guard !injected, let data = romData else { return }
            injected = true
            let b64 = data.base64EncodedString()
            let name = game.name
            let id = game.id
            let js = "window.loadRom && window.loadRom('\(b64)', '\(name)', '\(id)');"
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
        .toolbar(.hidden, for: .tabBar)   // 隐藏底部 TabBar，避免与工具栏重叠
        .statusBarHidden(false)
    }
}
