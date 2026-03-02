//
//  EditListingView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct EditListingView: View {
    @Environment(\.dismiss) private var dismiss

    let listing: Listing
    let onCancel: () -> Void
    let onSave: (Listing) -> Void

    @State private var title: String
    @State private var priceText: String
    @State private var status: ListingStatus

    init(listing: Listing, onCancel: @escaping () -> Void, onSave: @escaping (Listing) -> Void) {
        self.listing = listing
        self.onCancel = onCancel
        self.onSave = onSave
        _title = State(initialValue: listing.title)
        _priceText = State(initialValue: String(listing.price))
        _status = State(initialValue: listing.status)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Producto") {
                    TextField("Título", text: $title)

                    TextField("Precio", text: $priceText)
                        .keyboardType(.numberPad)

                    Picker("Estado", selection: $status) {
                        ForEach(ListingStatus.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                Section {
                    Button {
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let price = Int(priceText) ?? listing.price

                        var updated = listing
                        updated.title = cleanTitle.isEmpty ? listing.title : cleanTitle
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
