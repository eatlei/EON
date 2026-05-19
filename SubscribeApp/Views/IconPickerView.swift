import SwiftUI
import PhotosUI

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var icon: SubscriptionIcon

    private enum Mode: String, CaseIterable, Identifiable {
        case library = "图标库", appstore = "App Store", photo = "相册"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .library

    @State private var symbolQuery = ""
    private let symbols = [
        "sparkles", "brain.head.profile", "play.rectangle.fill", "music.note", "film.fill",
        "headphones", "tv", "cloud.fill", "externaldrive.fill", "hammer.fill",
        "chevron.left.forwardslash.chevron.right", "book.fill", "graduationcap.fill",
        "creditcard.fill", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis",
        "gamecontroller.fill", "newspaper.fill", "bolt.fill", "globe", "envelope.fill",
        "camera.fill", "paintbrush.fill", "lock.shield.fill", "wifi", "bag.fill",
        "cart.fill", "photo.fill"
    ]
    private var filteredSymbols: [String] {
        symbolQuery.isEmpty ? symbols : symbols.filter { $0.localizedCaseInsensitiveContains(symbolQuery) }
    }

    @State private var asQuery = ""
    @State private var region: AppStoreRegion = .cn
    @State private var results: [AppStoreApp] = []
    @State private var loading = false
    @State private var asError: String?

    @State private var photoItem: PhotosPickerItem?

    private let grid = [GridItem(.adaptive(minimum: 60), spacing: AppTheme.Space.m)]

    var body: some View {
        NavigationStack {
            AppScreen(bottomPadding: AppTheme.Space.l) {
                VStack(spacing: AppTheme.Space.l) {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch mode {
                    case .library: librarySection
                    case .appstore: appStoreSection
                    case .photo: photoSection
                    }
                }
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.tint(AppTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("恢复默认") { icon = .category; dismiss() }.tint(AppTheme.accent)
                }
            }
        }
    }

    private var librarySection: some View {
        VStack(spacing: AppTheme.Space.m) {
            searchField("搜索图标", text: $symbolQuery)
            LazyVGrid(columns: grid, spacing: AppTheme.Space.m) {
                ForEach(filteredSymbols, id: \.self) { s in
                    Button {
                        icon = .symbol(s); dismiss()
                    } label: {
                        Image(systemName: s)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 60, height: 60)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusSmall).stroke(AppTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var appStoreSection: some View {
        VStack(spacing: AppTheme.Space.m) {
            HStack(spacing: AppTheme.Space.s) {
                searchField("搜索 App，如 Netflix", text: $asQuery, onSubmit: runSearch)
                Menu {
                    Picker("", selection: $region) {
                        ForEach(AppStoreRegion.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe").font(.caption.weight(.bold))
                        Text(region.title).font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, AppTheme.Space.m).padding(.vertical, AppTheme.Space.m)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusSmall).stroke(AppTheme.hairline, lineWidth: 1))
                }
            }
            .onChange(of: region) { _, _ in
                if !asQuery.trimmingCharacters(in: .whitespaces).isEmpty { runSearch() }
            }

            if loading {
                ProgressView().tint(AppTheme.accent)
                    .frame(maxWidth: .infinity).padding(.vertical, AppTheme.Space.xl)
            } else if let asError {
                Text(asError).font(.subheadline).foregroundStyle(AppTheme.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, AppTheme.Space.xl)
            } else if results.isEmpty {
                Text("输入名称后回车搜索").font(.subheadline).foregroundStyle(AppTheme.tertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, AppTheme.Space.xl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { i, app in
                        if i > 0 { Hairline() }
                        Button { pick(app) } label: {
                            HStack(spacing: AppTheme.Space.m) {
                                AsyncImage(url: app.artworkURL) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 10).fill(AppTheme.surface)
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(app.name).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink).lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, AppTheme.Space.m)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            VStack(spacing: AppTheme.Space.m) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppTheme.accent)
                Text("从相册选择图片").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                Text("会自动裁成方形图标").font(.caption).foregroundStyle(AppTheme.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, AppTheme.Space.xxl)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 1))
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let id = IconStore.save(data: data) {
                    await MainActor.run { icon = .image(id); dismiss() }
                }
            }
        }
    }

    private func searchField(_ prompt: String, text: Binding<String>, onSubmit: (() -> Void)? = nil) -> some View {
        HStack(spacing: AppTheme.Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.tertiary)
            TextField(prompt, text: text)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { onSubmit?() }
        }
        .padding(AppTheme.Space.m)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusSmall).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private func runSearch() {
        let q = asQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        loading = true
        asError = nil
        Task {
            do {
                let r = try await AppStoreIconService.search(term: q, region: region)
                await MainActor.run {
                    results = r
                    loading = false
                    if r.isEmpty { asError = "没有找到相关 App" }
                }
            } catch {
                await MainActor.run {
                    loading = false
                    asError = "搜索失败，检查网络后重试"
                }
            }
        }
    }

    private func pick(_ app: AppStoreApp) {
        loading = true
        Task {
            do {
                let data = try await AppStoreIconService.fetchArtwork(app)
                if let id = IconStore.save(data: data) {
                    await MainActor.run { icon = .image(id); loading = false; dismiss() }
                } else {
                    await MainActor.run { loading = false; asError = "图标处理失败" }
                }
            } catch {
                await MainActor.run { loading = false; asError = "下载失败，重试" }
            }
        }
    }
}
