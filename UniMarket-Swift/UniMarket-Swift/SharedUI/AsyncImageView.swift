 import SwiftUI
import UIKit

private enum AsyncImageLoader {
    private static let memoryCache = NSCache<NSString, UIImage>()

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache.shared
        return URLSession(configuration: configuration)
    }()

    static func cachedImage(for key: String) -> UIImage? {
        memoryCache.object(forKey: key as NSString)
    }

    static func fetchImage(url: URL, cacheKey: String) async throws -> UIImage {
        if let image = cachedImage(for: cacheKey) {
            return image
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        memoryCache.setObject(image, forKey: cacheKey as NSString)
        return image
    }

    static func invalidateCache(for key: String) {
        memoryCache.removeObject(forKey: key as NSString)
    }
}

struct AsyncImageView: View {
    let urlString: String
    let cacheKey: String?

    @State private var image: UIImage?
    @State private var isLoading = false

    init(urlString: String, cacheKey: String? = nil) {
        self.urlString = urlString
        self.cacheKey = cacheKey
    }

    private var resolvedCacheKey: String {
        let trimmedCustomKey = cacheKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCustomKey.isEmpty {
            return trimmedCustomKey
        }

        return urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.gray)
            }
        }
        .task(id: resolvedCacheKey) {
            await loadImageIfNeeded()
        }
    }

    @MainActor
    private func loadImageIfNeeded() async {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, let url = URL(string: trimmedURL) else {
            image = nil
            isLoading = false
            return
        }

        let key = resolvedCacheKey
        if let cached = AsyncImageLoader.cachedImage(for: key) {
            image = cached
            isLoading = false
            return
        }

        isLoading = true
        do {
            let fetched = try await AsyncImageLoader.fetchImage(url: url, cacheKey: key)
            image = fetched
        } catch {
            image = nil
        }
        isLoading = false
    }

    static func invalidateCache(for key: String) {
        AsyncImageLoader.invalidateCache(for: key)
    }
}

struct AsyncImageViewPreview: PreviewProvider {
    static var previews: some View {
        AsyncImageView(urlString: "")
            .frame(width: 56, height: 56)
    }
}
