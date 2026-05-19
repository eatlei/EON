import SwiftUI
import PhotosUI

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var icon: SubscriptionIcon
    var appName: Binding<String>?

    private let originalImageID: String?

    init(icon: Binding<SubscriptionIcon>, appName: Binding<String>? = nil) {
        self._icon = icon
        self.appName = appName
        switch icon.wrappedValue {
        case .category: _working = State(initialValue: .category)
        case .symbol(let s): _working = State(initialValue: .symbol(s))
        case .monogram(let h): _working = State(initialValue: .monogram(h))
        case .image(let id):
            _working = State(initialValue: .existingImage(id))
            self.originalImageID = id
            return
        }
        self.originalImageID = nil
    }

    private enum WorkingIcon: Equatable {
        case category
        case symbol(String)
        case monogram(String)
        case imageData(Data)
        case existingImage(String)
    }
    @State private var working: WorkingIcon = .category
    @State private var pendingAppName: String?
    @State private var selectedAppID: Int?
    @State private var commitError: String?

    private enum Mode: CaseIterable, Identifiable {
        case library, appstore, photo
        var id: Int { hashValue }
        var title: String {
            switch self {
            case .library: String(localized: "图标库")
            case .appstore: String(localized: "App Store")
            case .photo: String(localized: "相册")
            }
        }
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
    @State private var photoPreview: Data?

    private let grid = [GridItem(.adaptive(minimum: 60), spacing: AppTheme.Space.m)]

    var body: some View {
        NavigationStack {
            AppScreen(bottomPadding: AppTheme.Space.l) {
                VStack(spacing: AppTheme.Space.l) {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if let commitError {
                        Text(commitError).font(.caption).foregroundStyle(AppTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

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
                    Button("完成") { commit() }.tint(AppTheme.accent)
                }
            }
        }
    }

    // MARK: Library (default + colors + symbols)

    private var librarySection: some View {
        VStack(spacing: AppTheme.Space.m) {
            VStack(alignment: .leading, spacing: AppTheme.Space.s) {
                Text("首字母颜色")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: AppTheme.Space.m)], spacing: AppTheme.Space.m) {
                    // 默认（分类色）
                    Button { working = .category; pendingAppName = nil; selectedAppID = nil } label: {
                        ZStack {
                            Circle().fill(AppTheme.surface)
                            Image(systemName: "a.square")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.secondary)
                        }
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(working == .category ? AppTheme.accent : AppTheme.hairline,
                                                 lineWidth: working == .category ? 3 : 1))
                    }
                    .buttonStyle(.plain)

                    ForEach(AppTheme.monogramColors, id: \.self) { hex in
                        Button { working = .monogram(hex); pendingAppName = nil; selectedAppID = nil } label: {
                            Circle()
                                .fill(Color(hexString: hex))
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(working == .monogram(hex) ? AppTheme.accent : AppTheme.hairline,
                                                         lineWidth: working == .monogram(hex) ? 3 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Divider()
            searchField("搜索图标", text: $symbolQuery)
            LazyVGrid(columns: grid, spacing: AppTheme.Space.m) {
                ForEach(filteredSymbols, id: \.self) { s in
                    Button { working = .symbol(s); pendingAppName = nil; selectedAppID = nil } label: {
                        Image(systemName: s)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(working == .symbol(s) ? AppTheme.accent : AppTheme.ink)
                            .frame(width: 60, height: 60)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                .stroke(working == .symbol(s) ? AppTheme.accent : AppTheme.hairline,
                                        lineWidth: working == .symbol(s) ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: App Store

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
                                if selectedAppID == app.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.accent)
                                }
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

    // MARK: Photo

    private var photoSection: some View {
        VStack(spacing: AppTheme.Space.m) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                VStack(spacing: AppTheme.Space.m) {
                    if let photoPreview, let ui = UIImage(data: photoPreview) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                        Text("已选择，点完成应用").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(AppTheme.accent)
                        Text("从相册选择图片").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
                        Text("会自动裁成方形图标").font(.caption).foregroundStyle(AppTheme.secondary)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, AppTheme.Space.xxl)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 1))
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoPreview = data
                            working = .imageData(data)
                            pendingAppName = nil
                            selectedAppID = nil
                        }
                    }
                }
            }
        }
    }

    private func searchField(_ prompt: LocalizedStringKey, text: Binding<String>, onSubmit: (() -> Void)? = nil) -> some View {
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
                    if r.isEmpty { asError = String(localized: "没有找到相关 App") }
                }
            } catch {
                await MainActor.run {
                    loading = false
                    asError = String(localized: "搜索失败，检查网络后重试")
                }
            }
        }
    }

    private func pick(_ app: AppStoreApp) {
        loading = true
        asError = nil
        Task {
            do {
                let data = try await AppStoreIconService.fetchArtwork(app)
                await MainActor.run {
                    working = .imageData(data)
                    pendingAppName = app.name
                    selectedAppID = app.id
                    loading = false
                }
            } catch {
                await MainActor.run { loading = false; asError = String(localized: "下载失败，重试") }
            }
        }
    }

    private func commit() {
        let finalIcon: SubscriptionIcon
        switch working {
        case .category:
            finalIcon = .category
        case .symbol(let s):
            finalIcon = .symbol(s)
        case .monogram(let h):
            finalIcon = .monogram(h)
        case .existingImage(let id):
            finalIcon = .image(id)
        case .imageData(let d):
            guard let newID = IconStore.save(data: d) else {
                commitError = String(localized: "图标处理失败")
                return
            }
            finalIcon = .image(newID)
        }
        if let oldID = originalImageID {
            if case .image(let keptID) = finalIcon, keptID == oldID {
                // unchanged, keep file
            } else {
                IconStore.delete(oldID)
            }
        }
        if let name = pendingAppName, let appName {
            appName.wrappedValue = name
        }
        icon = finalIcon
        dismiss()
    }
}
