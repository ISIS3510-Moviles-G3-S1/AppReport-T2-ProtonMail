import Foundation

struct ItemSummary: Identifiable, Hashable {
    let id: String
    let title: String
    let price: Int
    let imageName: String
}

protocol ItemSummarizable {
    var itemSummary: ItemSummary { get }
}

extension Product: ItemSummarizable {
    var itemSummary: ItemSummary {
        ItemSummary(
            id: id,
            title: title,
            price: price,
            imageName: imageName
        )
    }
}

extension Listing: ItemSummarizable {
    var itemSummary: ItemSummary {
        ItemSummary(
            id: id,
            title: title,
            price: price,
            imageName: imageName
        )
    }
}
