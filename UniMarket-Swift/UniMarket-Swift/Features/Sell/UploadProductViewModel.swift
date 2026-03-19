//
//  UploadProductViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import PhotosUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

final class UploadProductViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []

    @Published var selectedImages: [Image] = []
    @Published var imagesData: [Data] = []

    @Published var title: String = ""
    @Published var price: String = ""
    @Published var condition: String = "Good"
    @Published var description: String = ""

    @Published var isPosting: Bool = false
    @Published var errorMessage: String? = nil

    func loadSelectedPhotos() async {
        errorMessage = nil

        // Limpia previews anteriores (solo las de galería; mantiene las de cámara si quieres)
        await MainActor.run {
            selectedImages = []
            imagesData = []
        }

        for item in selectedItems {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    #if canImport(UIKit)
                    if let uiImage = UIImage(data: data) {
                        let swiftUIImage = Image(uiImage: uiImage)
                        await MainActor.run {
                            imagesData.append(data)
                            selectedImages.append(swiftUIImage)
                        }
                    } else {
                        await MainActor.run { errorMessage = "No se pudo leer una imagen." }
                    }
                    #else
                    await MainActor.run { imagesData.append(data) }
                    #endif
                }
            } catch {
                await MainActor.run { errorMessage = "Error cargando una de las fotos." }
            }
        }
    }

    func addImageFromCamera(_ uiImage: UIImage) {
        // agrega una foto tomada con cámara (máx 5)
        guard selectedImages.count < 5 else {
            errorMessage = "Máximo 5 fotos."
            return
        }

        if let data = uiImage.jpegData(compressionQuality: 0.85) {
            imagesData.append(data)
            selectedImages.append(Image(uiImage: uiImage))
        } else {
            errorMessage = "No se pudo procesar la foto."
        }
    }

    func removeImage(at index: Int) {
        if index < selectedImages.count { selectedImages.remove(at: index) }
        if index < imagesData.count { imagesData.remove(at: index) }

        // intenta mantener consistente con selectedItems (si venían de galería)
        if index < selectedItems.count { selectedItems.remove(at: index) }
    }

    var canPost: Bool {
        !imagesData.isEmpty &&
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(price) != nil
    }

    func postProduct(using productStore: ProductStore) async -> Bool {
        guard canPost, let parsedPrice = Int(price) else { return false }

        await MainActor.run {
            isPosting = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                self.isPosting = false
            }
        }

        do {
            let imageURLs = try await uploadListingImages()
            let input = CreateProductInput(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                price: parsedPrice,
                conditionTag: condition,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                imageURLs: imageURLs
            )

            _ = try await productStore.createProduct(input: input)
            resetForm()
            return true
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    private func uploadListingImages() async throws -> [String] {
        let listingID = UUID().uuidString
        var uploadedURLs: [String] = []

        for (index, data) in imagesData.enumerated() {
            guard let uiImage = UIImage(data: data) else {
                throw ImageUploadError.compressionFailed
            }

            let url = try await ImageUploadService.uploadListingImage(uiImage, listingId: listingID, index: index)
            uploadedURLs.append(url)
        }

        return uploadedURLs
    }

    @MainActor
    private func resetForm() {
        selectedItems = []
        selectedImages = []
        imagesData = []
        title = ""
        price = ""
        condition = "Good"
        description = ""
        errorMessage = nil
    }
}

// MARK: - Fix onChange iOS 17

private struct ItemsOnChangeFix: ViewModifier {
    let items: [PhotosPickerItem]
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: items) { _, _ in action() }
        } else {
            content.onChange(of: items) { _ in action() }
        }
    }
}
