import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum OrderSQLiteStoreError: LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case writeFailed(String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "Could not open the orders database. \(message)"
        case .prepareFailed(let message):
            return "Could not prepare the orders database. \(message)"
        case .writeFailed(let message):
            return "Could not save the order locally. \(message)"
        case .readFailed(let message):
            return "Could not read local orders. \(message)"
        }
    }
}

final class OrderSQLiteStore: @unchecked Sendable {
    static let shared = OrderSQLiteStore()

    private let queue = DispatchQueue(label: "com.unimarket.orders.sqlite")
    private let databaseURL: URL
    private var db: OpaquePointer?

    init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()
    }

    deinit {
        sqlite3_close(db)
    }

    func saveOrder(
        orderNumber: String,
        userID: String?,
        items cartItems: [CartItem],
        buyerName: String,
        buyerEmail: String,
        pickupLocation: String,
        paymentLastFour: String,
        paymentToken: String
    ) async throws -> Order {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let order = try self.saveOrderOnQueue(
                        orderNumber: orderNumber,
                        userID: userID,
                        items: cartItems,
                        buyerName: buyerName,
                        buyerEmail: buyerEmail,
                        pickupLocation: pickupLocation,
                        paymentLastFour: paymentLastFour,
                        paymentToken: paymentToken
                    )
                    continuation.resume(returning: order)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func saveOrderOnQueue(
        orderNumber: String,
        userID: String?,
        items cartItems: [CartItem],
        buyerName: String,
        buyerEmail: String,
        pickupLocation: String,
        paymentLastFour: String,
        paymentToken: String
    ) throws -> Order {
        try openIfNeeded()

        let orderID = UUID().uuidString
        let createdAt = Date()
        let orderItems = cartItems.map { cartItem in
            OrderItem(
                id: UUID().uuidString,
                orderID: orderID,
                productID: cartItem.product.id,
                sellerID: cartItem.product.sellerId,
                titleSnapshot: cartItem.product.title,
                priceSnapshot: cartItem.product.price,
                imageURLSnapshot: cartItem.product.primaryImageURL
            )
        }

        let order = Order(
            id: orderID,
            orderNumber: orderNumber,
            userID: normalizedUserID(userID),
            createdAt: createdAt,
            subtotal: orderItems.reduce(0) { $0 + $1.priceSnapshot },
            status: "Placed",
            buyerName: buyerName,
            buyerEmail: buyerEmail,
            pickupLocation: pickupLocation,
            paymentLastFour: paymentLastFour,
            paymentToken: paymentToken,
            items: orderItems
        )

        try execute("BEGIN TRANSACTION;")
        do {
            try insertOrder(order)
            for item in orderItems {
                try insertOrderItem(item)
            }
            try execute("COMMIT;")
            return order
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func orders(for userID: String?) async throws -> [Order] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let orders = try self.ordersOnQueue(for: userID)
                    continuation.resume(returning: orders)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func ordersOnQueue(for userID: String?) throws -> [Order] {
        try openIfNeeded()

        let sql = """
        SELECT id, order_number, user_id, created_at, subtotal, status, buyer_name, buyer_email,
               pickup_location, payment_last_four, payment_token
        FROM orders
        WHERE user_id = ?
        ORDER BY created_at DESC;
        """

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        try bindText(normalizedUserID(userID), to: 1, in: statement)

        var orders: [Order] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE {
                break
            }

            guard step == SQLITE_ROW else {
                throw OrderSQLiteStoreError.readFailed(lastErrorMessage)
            }

            let orderID = columnText(statement, 0)
            let items = try orderItems(for: orderID)
            let order = Order(
                id: orderID,
                orderNumber: columnText(statement, 1),
                userID: columnText(statement, 2),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                subtotal: Int(sqlite3_column_int(statement, 4)),
                status: columnText(statement, 5),
                buyerName: columnText(statement, 6),
                buyerEmail: columnText(statement, 7),
                pickupLocation: columnText(statement, 8),
                paymentLastFour: columnText(statement, 9),
                paymentToken: columnText(statement, 10),
                items: items
            )
            orders.append(order)
        }

        return orders
    }

    private func openIfNeeded() throws {
        guard db == nil else { return }

        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            let message = lastErrorMessage
            sqlite3_close(db)
            db = nil
            throw OrderSQLiteStoreError.openFailed(message)
        }

        try execute("PRAGMA foreign_keys = ON;")
        try createTablesIfNeeded()
    }

    private func createTablesIfNeeded() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS orders (
            id TEXT PRIMARY KEY,
            order_number TEXT NOT NULL,
            user_id TEXT NOT NULL,
            created_at REAL NOT NULL,
            subtotal INTEGER NOT NULL,
            status TEXT NOT NULL,
            buyer_name TEXT NOT NULL,
            buyer_email TEXT NOT NULL,
            pickup_location TEXT NOT NULL,
            payment_last_four TEXT NOT NULL,
            payment_token TEXT NOT NULL
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS order_items (
            id TEXT PRIMARY KEY,
            order_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            seller_id TEXT NOT NULL,
            title_snapshot TEXT NOT NULL,
            price_snapshot INTEGER NOT NULL,
            image_url_snapshot TEXT,
            FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
        );
        """)

        try execute("CREATE INDEX IF NOT EXISTS idx_orders_user_id_created_at ON orders(user_id, created_at);")
        try execute("CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);")
    }

    private func insertOrder(_ order: Order) throws {
        let sql = """
        INSERT INTO orders (
            id, order_number, user_id, created_at, subtotal, status, buyer_name, buyer_email,
            pickup_location, payment_last_four, payment_token
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        try bindText(order.id, to: 1, in: statement)
        try bindText(order.orderNumber, to: 2, in: statement)
        try bindText(order.userID, to: 3, in: statement)
        try bindDouble(order.createdAt.timeIntervalSince1970, to: 4, in: statement)
        try bindInt(order.subtotal, to: 5, in: statement)
        try bindText(order.status, to: 6, in: statement)
        try bindText(order.buyerName, to: 7, in: statement)
        try bindText(order.buyerEmail, to: 8, in: statement)
        try bindText(order.pickupLocation, to: 9, in: statement)
        try bindText(order.paymentLastFour, to: 10, in: statement)
        try bindText(order.paymentToken, to: 11, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw OrderSQLiteStoreError.writeFailed(lastErrorMessage)
        }
    }

    private func insertOrderItem(_ item: OrderItem) throws {
        let sql = """
        INSERT INTO order_items (
            id, order_id, product_id, seller_id, title_snapshot, price_snapshot, image_url_snapshot
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        try bindText(item.id, to: 1, in: statement)
        try bindText(item.orderID, to: 2, in: statement)
        try bindText(item.productID, to: 3, in: statement)
        try bindText(item.sellerID, to: 4, in: statement)
        try bindText(item.titleSnapshot, to: 5, in: statement)
        try bindInt(item.priceSnapshot, to: 6, in: statement)
        try bindOptionalText(item.imageURLSnapshot, to: 7, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw OrderSQLiteStoreError.writeFailed(lastErrorMessage)
        }
    }

    private func orderItems(for orderID: String) throws -> [OrderItem] {
        let sql = """
        SELECT id, order_id, product_id, seller_id, title_snapshot, price_snapshot, image_url_snapshot
        FROM order_items
        WHERE order_id = ?;
        """

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        try bindText(orderID, to: 1, in: statement)

        var items: [OrderItem] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE {
                break
            }

            guard step == SQLITE_ROW else {
                throw OrderSQLiteStoreError.readFailed(lastErrorMessage)
            }

            let item = OrderItem(
                id: columnText(statement, 0),
                orderID: columnText(statement, 1),
                productID: columnText(statement, 2),
                sellerID: columnText(statement, 3),
                titleSnapshot: columnText(statement, 4),
                priceSnapshot: Int(sqlite3_column_int(statement, 5)),
                imageURLSnapshot: columnOptionalText(statement, 6)
            )
            items.append(item)
        }

        return items
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw OrderSQLiteStoreError.prepareFailed(lastErrorMessage)
        }
        return statement
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage
            sqlite3_free(errorMessage)
            throw OrderSQLiteStoreError.writeFailed(message)
        }
    }

    private func bindText(_ value: String, to index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_text(statement, index, value, -1, sqliteTransient) == SQLITE_OK else {
            throw OrderSQLiteStoreError.writeFailed(lastErrorMessage)
        }
    }

    private func bindOptionalText(_ value: String?, to index: Int32, in statement: OpaquePointer?) throws {
        guard let value else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw OrderSQLiteStoreError.writeFailed(lastErrorMessage)
            }
            return
        }

        try bindText(value, to: index, in: statement)
    }

    private func bindInt(_ value: Int, to index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_int(statement, index, Int32(value)) == SQLITE_OK else {
            throw OrderSQLiteStoreError.writeFailed(lastErrorMessage)
        }
    }

    private func bindDouble(_ value: Double, to index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw OrderSQLiteStoreError.writeFailed(lastErrorMessage)
        }
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private func columnOptionalText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return columnText(statement, index)
    }

    private func normalizedUserID(_ userID: String?) -> String {
        let trimmed = userID?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return "guest" }
        return trimmed
    }

    private var lastErrorMessage: String {
        guard let db else { return "No database connection." }
        return String(cString: sqlite3_errmsg(db))
    }

    private static func defaultDatabaseURL() -> URL {
        let fileManager = FileManager.default
        if let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return supportURL
                .appendingPathComponent("UniMarket", isDirectory: true)
                .appendingPathComponent("orders.sqlite")
        }

        return fileManager.temporaryDirectory.appendingPathComponent("orders.sqlite")
    }
}
