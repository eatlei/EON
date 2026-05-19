import StoreKit
import SwiftUI

@MainActor
final class TipStore: ObservableObject {
    static let productIDs = [
        "com.codex.SubscribeApp.tip.coffee",
        "com.codex.SubscribeApp.tip.snack",
        "com.codex.SubscribeApp.tip.meal"
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
