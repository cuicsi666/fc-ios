import Foundation
import SwiftUI

// 游戏库管理器：管理内置游戏 + 商店下载的游戏 + ROM 加载
final class GameStore: ObservableObject {
    @Published var builtInGames: [Game] = []
    @Published var downloadedGames: [Game] = []   // 商店下载的（持久化到 Documents）
    @Published var catalogGames: [CatalogGame] = [] // 远程目录
    @Published var catalogLoaded = false
    @Published var catalogError: String?

    // 远程商店目录 URL（飞牛内网；外网可通过 cuicsi.cn 反代同目录）
    private let catalogURL = "http://6.6.6.130:8099/updates/nes/catalog.json"
    // 下载状态跟踪
    @Published var downloading: [String: Bool] = [:]
    @Published var progress: [String: Double] = [:]

    private let docsDir: URL

    init() {
        let fm = FileManager.default
        docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        loadBuiltIn()
        loadDownloaded()
    }

    // 内置预设游戏
    private func loadBuiltIn() {
        builtInGames = [
            Game(id: "super-mario", name: "超级玛丽", enName: "Super Mario Bros.",
                 romFileName: "mario.nes", cover: "🍄", coverColor: "#E74C3C",
                 desc: "1985 · 任天堂 · 横版过关"),
            Game(id: "contra", name: "魂斗罗", enName: "Contra",
                 romFileName: "contra.nes", cover: "🔫", coverColor: "#2C3E50",
                 desc: "1987 · Konami · 动作射击"),
            Game(id: "battle-city", name: "坦克大战", enName: "Battle City",
                 romFileName: "battlecity.nes", cover: "🛡️", coverColor: "#27AE60",
                 desc: "1985 · Namco · 塔防射击"),
        ]
    }

    // 读取内置 ROM 数据
    func builtInRom(_ name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil,
                                        subdirectory: "roms") else {
            // 兜底：直接在 bundle 根找
            if let u2 = Bundle.main.url(forResource: name, withExtension: nil) {
                return try? Data(contentsOf: u2)
            }
            return nil
        }
        return try? Data(contentsOf: url)
    }

    // 读取任意游戏的 ROM（内置优先，其次已下载）
    func romData(for game: Game) -> Data? {
        if game.isBuiltIn {
            return builtInRom(game.romFileName)
        }
        // 下载的游戏存 Documents/roms/
        let url = docsDir.appendingPathComponent("roms").appendingPathComponent(game.romFileName)
        return try? Data(contentsOf: url)
    }

    // MARK: - 商店

    func loadCatalog() {
        catalogLoaded = false
        catalogError = nil
        guard let url = URL(string: catalogURL) else { return }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            DispatchQueue.main.async {
                self.catalogLoaded = true
                if let err = err {
                    self.catalogError = "目录加载失败：\(err.localizedDescription)"
                    return
                }
                guard let data = data,
                      let cat = try? JSONDecoder().decode(Catalog.self, from: data) else {
                    self.catalogError = "目录解析失败"
                    return
                }
                self.catalogGames = cat.games
            }
        }.resume()
    }

    // 下载 ROM 到 Documents，完成后自动加入已下载列表
    func download(_ cg: CatalogGame) {
        guard let url = URL(string: cg.romURL) else { return }
        downloading[cg.id] = true
        progress[cg.id] = 0

        URLSession.shared.downloadTask(with: url) { tmpURL, resp, err in
            DispatchQueue.main.async {
                self.downloading[cg.id] = false
                self.progress[cg.id] = 1.0
                if let err = err {
                    self.catalogError = "下载失败：\(err.localizedDescription)"
                    return
                }
                guard let tmpURL = tmpURL else {
                    self.catalogError = "下载失败：无数据"
                    return
                }
                do {
                    let romDir = self.docsDir.appendingPathComponent("roms")
                    try FileManager.default.createDirectory(at: romDir, withIntermediateDirectories: true)
                    let fileName = "\(cg.id).nes"
                    let dest = romDir.appendingPathComponent(fileName)
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.moveItem(at: tmpURL, to: dest)

                    let game = Game(id: cg.id, name: cg.name, enName: cg.enName,
                                    romFileName: fileName, cover: cg.cover,
                                    coverColor: cg.coverColor, desc: cg.desc,
                                    isBuiltIn: false, downloadURL: cg.romURL)
                    // 去重后加入
                    if !self.downloadedGames.contains(where: { $0.id == cg.id }) {
                        self.downloadedGames.append(game)
                    }
                    self.saveDownloaded()
                } catch {
                    self.catalogError = "保存失败：\(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func isDownloaded(_ id: String) -> Bool {
        return downloadedGames.contains(where: { $0.id == id })
    }

    // MARK: - 持久化已下载游戏列表

    private func downloadedListURL() -> URL {
        docsDir.appendingPathComponent("downloaded.json")
    }

    private func saveDownloaded() {
        guard let data = try? JSONEncoder().encode(downloadedGames) else { return }
        try? data.write(to: downloadedListURL())
    }

    private func loadDownloaded() {
        guard let data = try? Data(contentsOf: downloadedListURL()),
              let games = try? JSONDecoder().decode([Game].self, from: data) else { return }
        downloadedGames = games
    }

    // 删除已下载游戏
    func removeDownloaded(_ game: Game) {
        downloadedGames.removeAll { $0.id == game.id }
        saveDownloaded()
        let url = docsDir.appendingPathComponent("roms").appendingPathComponent(game.romFileName)
        try? FileManager.default.removeItem(at: url)
    }
}
