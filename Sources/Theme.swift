import SwiftUI

// 统一配色
enum T {
    static let bg = Color(red: 0.05, green: 0.06, blue: 0.13)
    static let card = Color(red: 0.09, green: 0.11, blue: 0.20)
    static let card2 = Color(red: 0.12, green: 0.14, blue: 0.25)
    static let txt = Color(red: 0.93, green: 0.95, blue: 1.0)
    static let sub = Color(red: 0.54, green: 0.58, blue: 0.68)
    static let accent = Color(red: 1.0, green: 0.35, blue: 0.43)
    static let accent2 = Color(red: 0.29, green: 0.62, blue: 1.0)
    static let line = Color(red: 0.16, green: 0.19, blue: 0.31)
}

// 十六进制颜色 → Color
func hexColor(_ hex: String) -> Color {
    var h = hex.trimmingCharacters(in: .whitespaces)
    if h.hasPrefix("#") { h.removeFirst() }
    var rgb: UInt64 = 0
    Scanner(string: h).scanHexInt64(&rgb)
    let r = Double((rgb >> 16) & 0xFF) / 255.0
    let g = Double((rgb >> 8) & 0xFF) / 255.0
    let b = Double(rgb & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b)
}
