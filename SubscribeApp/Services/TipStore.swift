import StoreKit
import SwiftUI

@MainActor
final class TipStore: ObservableObject {
    // 这三个 Product ID 必须和 App Store Connect 里新建 In-App Purchase 用的
    // "Product ID"逐字一致。bundle id (com.leon.eon) 是惯例前缀,后面接 tip.<档>。
    static let productIDs = [
        "com.leon.eon.tip.coffee",
        "com.leon.eon.tip.snack",
        "com.leon.eon.tip.meal"
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var loaded = false
    @Published var purchasingID: Product.ID?
    @Published var thanksShown = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task.detached {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func load() async {
        guard !loaded else { return }
        do {
            let items = try await Product.products(for: TipStore.productIDs)
            products = items.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
        loaded = true
    }

    func purchase(_ product: Product) async {
        purchasingID = product.id
        defer { purchasingID = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    thanksShown = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // 购买失败静默处理，UI 保持原状
        }
    }
}
