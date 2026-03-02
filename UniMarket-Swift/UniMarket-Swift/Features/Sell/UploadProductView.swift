//
//  UploadProductView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit
#endif

struct UploadProductView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = UploadProductViewModel()

    @State private var showCamera = false

    private let conditions = ["Good", "Like New"]
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                header

                photoSection

                labeledTextField(title: "Título", placeholder: "Ej: Chaqueta vintage", text: $vm.title)

                labeledTextField(title: "Precio", placeholder: "Ej: 18000", text: $vm.price)
                    .keyboardType(.numberPad)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Condición").font(.headline)
                    Picker("Condición", selection: $vm.condition) {
                        ForEach(conditions, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Descripción").font(.headline)
                    TextEditor(text: $vm.description)
                        .frame(height: 120)
                        .padding(10)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(14)
                }

                if let msg = vm.errorMessage {
                    Text(msg)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button {
                    Task {
                        await vm.postMock()
                        dismiss()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if vm.isPosting { ProgressView().padding(.trailing, 6) }
                        Text(vm.isPosting ? "Publicando..." : "Publicar")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding()
                }
                .background(vm.canPost ? Color.green.opacity(0.75) : Color.gray.opacity(0.35))
                .foregroundColor(.white)
                .cornerRadius(16)
                .disabled(!vm.canPost || vm.isPosting)

                Spacer(minLength: 20)
            }
            .padding()
            .padding(.bottom, 20)
        }
        .onChange(of: vm.selectedItems) { _, _ in
            Task {
                await vm.loadSelectedPhotos()
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(source: .camera) { uiImage in
                vm.addImageFromCamera(uiImage)
            }
        }
    }


    // MARK: - UI pieces

    private var header: some View {
        HStack {
            Text("Subir producto")
                .font(.title2).bold()
            Spacer()
            Button("Cerrar") { dismiss() }
                .foregroundColor(.secondary)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fotos")
                .font(.headline)

            HStack(spacing: 12) {
                // Galería (multi)
                PhotosPicker(
                    selection: $vm.selectedItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Galería")
                        Spacer()
                        Text("\(vm.selectedItems.count)/5")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)

                // Cámara
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera")
                        Text("Cámara")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }

            if !vm.selectedImages.isEmpty {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(vm.selectedImages.enumerated()), id: \.offset) { index, img in
                        ZStack(alignment: .topTrailing) {
                            img
                                .resizable()
                                .scaledToFill()
                                .frame(height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .clipped()

                            Button {
                                vm.removeImage(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                        }
                    }
                }
            } else {
                Text("Selecciona hasta 5 fotos o toma una con la cámara.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func labeledTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            TextField(placeholder, text: text)
                .padding(12)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(14)
        }
    }
}
