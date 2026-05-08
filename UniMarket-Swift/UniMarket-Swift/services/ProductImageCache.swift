import Foundation
import UIKit

final class ProductImageCache {
    static let shared = ProductImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL, cost: imageCost(for: image))
    }

    func remove(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    func clear() {
        cache.removeAllObjects()
    }

    private func imageCost(for image: UIImage) -> Int {
        let scale = image.scale
        let width = Int(image.size.width * scale)
        let height = Int(image.size.height * scale)
        return max(width * height * 4, 1)
    }
}
