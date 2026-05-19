import SwiftUI

struct CartToolbarButton: View {
    @EnvironmentObject private var cartStore: CartStore

    var body: some View {
        NavigationLink {
            CartView()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: cartStore.itemCount > 0 ? "cart.fill" : "cart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 38, height: 38)

                if cartStore.itemCount > 0 {
                    Text(badgeText)
                        .font(.poppinsSemiBold(9))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -2)
                }
            }
        }
        .accessibilityLabel("Cart")
    }

    private var badgeText: String {
        cartStore.itemCount > 99 ? "99+" : "\(cartStore.itemCount)"
    }
}
