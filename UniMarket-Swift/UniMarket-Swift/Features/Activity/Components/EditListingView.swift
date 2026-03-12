//
//  EditListingView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct EditListingView: View {
    @Environment(\.dismiss) private var dismiss

    let product: Product
    let onCancel: () -> Void
    let onSave: (Product) -> Void

    @State private var title: String
    @State private var priceText: String
    @State private var status: ProductStatus

    init(product: Product, onCancel: @escaping () -> Void, onSave: @escaping (Product) -> Void) {
        self.product = product
        self.onCancel = onCancel
        self.onSave = onSave
        _title = State(initialValue: product.title)
        _priceText = State(initialValue: String(product.price))
        _status = State(initialValue: product.status)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Producto") {
                    TextField("Título", text: $title)

                    TextField("Precio", text: $priceText)
                        .keyboardType(.numberPad)

                    Picker("Estado", selection: $status) {
                        ForEach(ProductStatus.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                Section {
                    Button {
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let price = Int(priceText) ?? product.price

                        var updated = product
                        updated.title = cleanTitle.isEmpty ? product.title : cleanTitle
                        updated.price = price
                        updated.status = status

                        onSave(updated)
                        dismiss()
                    } label: {
                        Text("Save Changes").fontWeight(.semibold)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Int(priceText) == nil)
                }
            }
            .navigationTitle("Edit Listing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}
