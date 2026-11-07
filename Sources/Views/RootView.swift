import SwiftUI

// 主界面：底部 Tab（游戏库 / 商店）
struct RootView: View {
    @StateObject private var store = GameStore()

    var body: some View {
        TabView {
            NavigationStack {
                LibraryView(store: store)
            }
            .tabItem { Label("游戏库", systemImage: "gamecontroller.fill") }

            NavigationStack {
                StoreView(store: store)
            }
            .tabItem { Label("商店", systemImage: "bag.fill") }
        }
        .tint(T.accent)
        .preferredColorScheme(.dark)
    }
}

// 游戏库主页：内置游戏 + 已下载游戏，网格排布
struct LibraryView: View {
    @ObservedObject var store: GameStore

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 顶部标题
                header

                // 内置游戏
                sectionTitle("🎮 经典游戏")
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.builtInGames) { game in
                        GameCard(game: game, romData: store.romData(for: game))
                    }
                }

                // 已下载游戏
                if !store.downloadedGames.isEmpty {
                    sectionTitle("📦 我的下载")
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.downloadedGames) { game in
                            GameCard(game: game, romData: store.romData(for: game))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(T.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("红白机")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(T.txt)
                Spacer()
                Text("FC · NES")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(T.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(T.accent.opacity(0.14))
                    .clipShape(Capsule())
            }
            Text("和小伙伴一起玩经典游戏")
                .font(.system(size: 14))
                .foregroundColor(T.sub)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(T.txt)
            .padding(.top, 4)
    }
}

// 游戏卡片
struct GameCard: View {
    let game: Game
    let romData: Data?

    var body: some View {
        NavigationLink {
            EmulatorView(game: game, romData: romData)
        } label: {
            VStack(spacing: 0) {
                // 封面区
                ZStack {
                    LinearGradient(colors: [hexColor(game.coverColor).opacity(0.9),
                                            hexColor(game.coverColor).opacity(0.45)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 6) {
                        Text(game.cover)
                            .font(.system(size: 40))
                        Text(game.enName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(height: 118)

                // 信息区
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(T.txt)
                        .lineLimit(1)
                    Text(game.desc)
                        .font(.system(size: 11))
                        .foregroundColor(T.sub)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .background(T.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
