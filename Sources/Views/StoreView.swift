import SwiftUI

// 商店：从远程目录下载 ROM 并直接加载
struct StoreView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if store.catalogError != nil {
                    errorBanner
                }

                if !store.catalogLoaded && store.catalogError == nil {
                    // 加载中
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(T.accent)
                        Text("正在加载商店…")
                            .font(.system(size: 13))
                            .foregroundColor(T.sub)
                        Spacer()
                    }
                    .padding(.vertical, 30)
                }

                // 目录列表
                ForEach(store.catalogGames, id: \.id) { cg in
                    StoreCard(store: store, cg: cg)
                }

                if store.catalogLoaded && store.catalogGames.isEmpty && store.catalogError == nil {
                    Text("商店暂无游戏")
                        .font(.system(size: 14))
                        .foregroundColor(T.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(T.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if store.catalogGames.isEmpty {
                store.loadCatalog()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("商店")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(T.txt)
            Text("下载 ROM 文件，直接加载红白机")
                .font(.system(size: 14))
                .foregroundColor(T.sub)
        }
    }

    private var errorBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(store.catalogError ?? "")
                .font(.system(size: 13))
                .foregroundColor(T.sub)
            Spacer()
            Button("重试") { store.loadCatalog() }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(T.accent2)
        }
        .padding(12)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// 商店条目卡片
struct StoreCard: View {
    @ObservedObject var store: GameStore
    let cg: CatalogGame

    var body: some View {
        HStack(spacing: 12) {
            // 封面
            ZStack {
                LinearGradient(colors: [hexColor(cg.coverColor).opacity(0.9),
                                        hexColor(cg.coverColor).opacity(0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(cg.cover)
                    .font(.system(size: 26))
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 信息
            VStack(alignment: .leading, spacing: 3) {
                Text(cg.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(T.txt)
                Text(cg.enName)
                    .font(.system(size: 11))
                    .foregroundColor(T.sub)
                    .lineLimit(1)
                Text("\(cg.sizeKB) KB")
                    .font(.system(size: 11))
                    .foregroundColor(T.sub.opacity(0.8))
            }
            Spacer()

            // 按钮
            if store.isDownloaded(cg.id) {
                Text("已下载")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
            } else if store.downloading[cg.id] == true {
                ProgressView()
                    .tint(T.accent)
                    .frame(width: 70)
            } else {
                Button {
                    store.download(cg)
                } label: {
                    Label("下载", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(T.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(T.line, lineWidth: 1))
    }
}
