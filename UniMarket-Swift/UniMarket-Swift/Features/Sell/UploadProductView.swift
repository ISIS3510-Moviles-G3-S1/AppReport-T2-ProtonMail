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
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    photoSection

                    labeledTextField(title: "Title", placeholder: "Ex: Vintage Jacket", text: $vm.title)

                    labeledTextField(title: "Price", placeholder: "Ex: 18000", text: $vm.price)
                        .keyboardType(.numberPad)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Condition")
                            .font(.poppinsSemiBold(16))
                        Picker("Condition", selection: $vm.condition) {
                            ForEach(conditions, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.poppinsSemiBold(16))
                        TextEditor(text: $vm.description)
                            .font(.poppinsRegular(15))
                            .frame(height: 120)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if let msg = vm.errorMessage {
                        Text(msg)
                            .foregroundStyle(.red)
                            .font(.poppinsRegular(12))
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
                            Text(vm.isPosting ? "Publishing..." : "Publish")
                                .font(.poppinsSemiBold(16))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                        }
                        .padding()
                    }
                    .background(vm.canPost ? AppTheme.accent : AppTheme.secondaryText.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .disabled(!vm.canPost || vm.isPosting)

                    Spacer(minLength: 20)
                }
                .padding()
                .padding(.bottom, 20)
            }
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

    private var header: some View {
        HStack {
            Text("Upload product")
                .font(.poppinsBold(24))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Button("Close") { dismiss() }
                .font(.poppinsRegular(14))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pictures")
                .font(.poppinsSemiBold(16))

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $vm.selectedItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Gallery")
                            .font(.poppinsRegular(14))
                        Spacer()
                        Text("\(vm.selectedItems.count)/5")
                            .font(.poppinsRegular(12))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera")
                        Text("Camera")
                            .font(.poppinsRegular(14))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                                    .font(.poppinsBold(12))
                                    .foregroundStyle(.white)
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
                Text("Select 5 photos or upload them.")
                    .font(.poppinsRegular(12))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func labeledTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.poppinsSemiBold(16))
            TextField(placeholder, text: text)
                .font(.poppinsRegular(15))
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
