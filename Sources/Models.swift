import Foundation
import SwiftUI

// 游戏模型
struct Game: Identifiable, Codable, Hashable {
    let id: String
    let name: String          // 中文名
    let enName: String        // 英文名
    let romFileName: String   // 内置 ROM 文件名
    let cover: String         // 封面 emoji / 缩写
    let coverColor: String    // 封面渐变色（十六进制）
    let desc: String
    let isBuiltIn: Bool
    let downloadURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, enName, romFileName, cover, coverColor, desc, isBuiltIn, downloadURL
    }

    init(id: String, name: String, enName: String, romFileName: String,
         cover: String, coverColor: String, desc: String,
         isBuiltIn: Bool = true, downloadURL: String? = nil) {
        self.id = id
        self.name = name
        self.enName = enName
        self.romFileName = romFileName
        self.cover = cover
        self.coverColor = coverColor
        self.desc = desc
        self.isBuiltIn = isBuiltIn
        self.downloadURL = downloadURL
    }
}

// 商店目录（从远程拉取）
struct Catalog: Codable {
    let games: [CatalogGame]
}

struct CatalogGame: Codable {
    let id: String
    let name: String
    let enName: String
    let cover: String
    let coverColor: String
    let desc: String
    let romURL: String
    let sizeKB: Int
}
