import SwiftUI
import Kingfisher

struct CachedRemoteImageView: View {
    enum PlaceholderStyle {
        case image
        case profile

        var systemName: String {
            switch self {
            case .image:
                return "photo"
            case .profile:
                return "person.circle.fill"
            }
        }
    }

    let urlString: String
    let cacheKey: String?
    let placeholderStyle: PlaceholderStyle

    init(
        urlString: String,
        cacheKey: String? = nil,
        placeholderStyle: PlaceholderStyle = .image
    ) {
        self.urlString = urlString
        self.cacheKey = cacheKey
        self.placeholderStyle = placeholderStyle
    }

    private var resolvedURL: URL? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        return URL(string: trimmedURL)
    }

    private var placeholderView: some View {
        GeometryReader { geo in
            // Compute a symbol size relative to the parent container so it scales across cards
            let minSide = min(geo.size.width, geo.size.height)
            let scale: CGFloat = (placeholderStyle == .profile) ? 0.45 : 0.28
            let computedSize = max(24, minSide * scale)

            ZStack {
                // subtle background behind the symbol to improve contrast
                RoundedRectangle(cornerRadius: computedSize * 0.35)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: computedSize * 1.6, height: computedSize * 1.6)

                Image(systemName: placeholderStyle.systemName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: computedSize, height: computedSize)
                    .foregroundStyle(Color.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        // Give GeometryReader a flexible size so outer frames (cards) control layout
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        Group {
            if let resolvedURL {
                KFImage(resolvedURL)
                    .placeholder {
                        placeholderView
                    }
                    .onFailure { _ in }
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholderView
            }
        }
    }

    static func invalidateCache(for key: String) {
        ImageCache.default.removeImage(forKey: key)
    }
}

struct CachedRemoteImageViewPreview: PreviewProvider {
    static var previews: some View {
        CachedRemoteImageView(urlString: "")
            .frame(width: 56, height: 56)
    }
}
