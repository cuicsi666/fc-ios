# 红白机（FC/NES 模拟器）

iOS 版红白机模拟器，内置 jsnes 内核（WKWebView 承载），支持：

- 🎮 直接玩红白机游戏（方向键 + AB 键 + SELECT/START）
- 🛍️ 商店：下载 ROM 文件并直接加载
- 📦 预设 3 款经典游戏：《超级玛丽》《魂斗罗》《坦克大战》
- 📐 竖屏排布（按老板截图：顶栏标题 + 游戏画面 + 控制区 + 设置条）

## 技术栈

- SwiftUI + WKWebView
- [jsnes](https://github.com/bfirsh/jsnes)（JavaScript NES 模拟器内核，MIT）
- XcodeGen 生成工程，GitHub Actions（macos-15）出未签名 IPA

## 目录结构

```
Sources/            Swift 源码（App 入口、模型、游戏库、商店、模拟器视图）
Resources/
  emulator/         jsnes 内核 + 模拟器前端（index.html / nes.js / jsnes.min.js）
  roms/             3 款预设 ROM（内置）
  Assets.xcassets/  应用图标
project.yml         XcodeGen 配置
.github/workflows/  IPA 构建
```

## 商店 ROM 托管

- 目录：飞牛 g-navigation 站点 `site/updates/nes/catalog.json`
- ROM：同目录 `roms/*.nes`
- App 内置预设 3 款，商店可下载更多（双截龙II / 洛克人 / 冒险岛 / 雪人兄弟）

## 构建

GitHub Actions `build.yml`：XcodeGen → xcodebuild（no-codesign）→ 打包 `红白机_V1.ipa`。

## 版权说明

ROM 文件为经典游戏镜像，仅供个人学习与怀旧使用，请支持正版。
