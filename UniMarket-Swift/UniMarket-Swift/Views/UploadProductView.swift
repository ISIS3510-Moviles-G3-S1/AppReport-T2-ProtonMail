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
    private let analytics = AnalyticsService.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var productStore: ProductStore
    @EnvironmentObject private var session: SessionManager
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var vm = UploadProductViewModel()

    @State private var showCamera = false
    @State private var showDrafts = false
    @State private var showClothingAnalysis = false
    @State private var isTagPickerExpanded = false
    @State private var hasAppliedAIDraft = false
    
    // Optional: Pre-fill data from AI analysis
    var aiAnalysisImage: UIImage?
    var aiListingDraft: AIListingDraft?

    private let conditions = ["Good", "Like New"]
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private var cardBackground: Color { AppTheme.cardBackground }
    private var borderColor: Color { AppTheme.borderColor }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if !networkMonitor.isConnected {
                        offlineDraftBanner
                    }
                    photoSection

                    labeledTextField(title: "Title", placeholder: "Ex: Vintage Jacket", text: $vm.title)

                    labeledTextField(title: "Price", placeholder: "Ex: 18000", text: $vm.price)
                        .keyboardType(.numberPad)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Condition")
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(AppTheme.primaryText)

                        Picker("Condition", selection: $vm.condition) {
                            ForEach(conditions, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(AppTheme.primaryText)

                        TextEditor(text: $vm.description)
                            .font(.poppinsRegular(15))
                            .foregroundStyle(AppTheme.primaryText)
                            .scrollContentBackground(.hidden)
                            .frame(height: 120)
                            .padding(10)
                            .background(cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(borderColor, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    tagsSection

                    if let msg = vm.errorMessage {
                        Text(msg)
                            .foregroundStyle(.red)
                            .font(.poppinsRegular(12))
                    }

                    if let info = vm.infoMessage {
                        Text(info)
                            .foregroundStyle(AppTheme.accentAlt)
                            .font(.poppinsRegular(12))
                    }

                    Button {
                        Task {
                            let outcome = await vm.postProduct(using: productStore)
                            switch outcome {
                            case .published, .queued:
                                dismiss()
                            case .failed:
                                break
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isPosting {
                                ProgressView()
                                    .tint(AppTheme.primaryText)
                                    .padding(.trailing, 6)
                            }
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
        .onAppear {
            analytics.track(.uploadScreenViewed())

            guard !hasAppliedAIDraft, let aiListingDraft else { return }
            vm.applyAIDraft(aiListingDraft, image: aiAnalysisImage)
            hasAppliedAIDraft = true
        }
        .onChange(of: vm.selectedItems) { _, _ in
            analytics.track(.listingPhotosSelected(count: vm.selectedItems.count, source: "gallery"))
            Task {
                await vm.loadSelectedPhotos()
            }
        }
        .onChange(of: networkMonitor.isConnected) { wasConnected, isConnected in
            guard wasConnected, !isConnected else { return }
            saveDraft(message: "Connection lost — saved this form to Drafts.")
        }
        .onDisappear {
            guard !networkMonitor.isConnected else { return }
            saveDraft(message: "Draft saved.")
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(source: .camera) { uiImage in
                vm.addImageFromCamera(uiImage)
                analytics.track(.listingPhotosSelected(count: vm.selectedImages.count, source: "camera"))
            }
        }
        .sheet(isPresented: $showDrafts) {
            ListingDraftsView(userID: session.uid) { draft in
                Task {
                    await vm.restoreDraft(draft)
                }
            }
        }
        .navigationDestination(isPresented: $showClothingAnalysis) {
            ClothingAnalysisView()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Upload product")
                .font(.poppinsBold(24))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Button {
                showDrafts = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                    Text("Drafts")
                }
                .font(.poppinsSemiBold(13))
                .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)

            Button("Close") { dismiss() }
                .font(.poppinsRegular(14))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var offlineDraftBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text("Offline draft mode")
                    .font(.poppinsSemiBold(13))
                    .foregroundStyle(AppTheme.primaryText)
                Text("This listing can be saved to Drafts until connection returns.")
                    .font(.poppinsRegular(11))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 0)

            Button("Save Draft") {
                saveDraft(message: "Draft saved.")
            }
            .font(.poppinsSemiBold(12))
            .foregroundStyle(AppTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(vm.hasDraftContent ? AppTheme.accent : AppTheme.secondaryText.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .disabled(!vm.hasDraftContent)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func saveDraft(message: String) {
        Task {
            await vm.saveDraftIfNeeded(for: session.uid, message: message)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pictures")
                .font(.poppinsSemiBold(16))
                .foregroundStyle(AppTheme.primaryText)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $vm.selectedItems,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundStyle(AppTheme.primaryText)
                            Text("Gallery")
                                .font(.poppinsRegular(14))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            Text("\(vm.selectedItems.count)/5")
                                .font(.poppinsRegular(12))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding()
                        .background(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(borderColor, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)

                    Button {
                        showCamera = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera")
                                .foregroundStyle(AppTheme.primaryText)
                            Text("Camera")
                                .font(.poppinsRegular(14))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(borderColor, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }

                Button {
                    showClothingAnalysis = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                        Text("AI Analyze")
                            .font(.poppinsRegular(14))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accentAlt.opacity(0.2))
                    .foregroundStyle(AppTheme.accentAlt)
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
                                analytics.track(.listingPhotoRemoved(remainingCount: max(vm.selectedImages.count - 1, 0)))
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

    private var tagsSection: some View {
        let allTags = Array(Set(productStore.products.flatMap(\.tags))).sorted()
        let filteredTags = vm.filteredAvailableTags(from: allTags)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.poppinsSemiBold(16))
                .foregroundStyle(AppTheme.primaryText)

            if !vm.selectedTags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(vm.selectedTags, id: \.self) { tag in
                        Button {
                            vm.toggleTag(tag)
                        } label: {
                            HStack(spacing: 6) {
                                Text(tag.capitalized)
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                            .font(.poppinsSemiBold(12))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.accentAlt.opacity(0.35))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isTagPickerExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("Choose tags")
                            .font(.poppinsRegular(15))
                            .foregroundStyle(vm.selectedTags.isEmpty ? AppTheme.secondaryText : AppTheme.primaryText)
                        Spacer()
                        Image(systemName: isTagPickerExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(12)
                    .background(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                if isTagPickerExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Search tags", text: $vm.tagSearchText)
                            .font(.poppinsRegular(15))
                            .foregroundStyle(AppTheme.primaryText)
                            .tint(AppTheme.primaryText)
                            .padding(12)
                            .background(AppTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                if filteredTags.isEmpty {
                                    Text("No matching tags.")
                                        .font(.poppinsRegular(13))
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .padding(.vertical, 4)
                                } else {
                                    ForEach(filteredTags, id: \.self) { tag in
                                        Button {
                                            vm.toggleTag(tag)
                                        } label: {
                                            HStack {
                                                Text(tag.capitalized)
                                                    .font(.poppinsRegular(14))
                                                    .foregroundStyle(AppTheme.primaryText)
                                                Spacer()
                                                Image(systemName: "plus")
                                                    .foregroundStyle(AppTheme.accent)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(AppTheme.cardBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                    .padding(12)
                    .background(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            HStack(spacing: 10) {
                TextField("Add a new tag", text: $vm.customTagInput)
                    .font(.poppinsRegular(15))
                    .foregroundStyle(AppTheme.primaryText)
                    .tint(AppTheme.primaryText)
                    .padding(12)
                    .background(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Add") {
                    vm.addCustomTag()
                }
                .font(.poppinsSemiBold(14))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(vm.normalizedCustomTag.isEmpty)
            }

            Text("You can select up to 8 tags.")
                .font(.poppinsRegular(12))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func labeledTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.poppinsSemiBold(16))
                .foregroundStyle(AppTheme.primaryText)

            TextField(placeholder, text: text)
                .font(.poppinsRegular(15))
                .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.primaryText)
                .padding(12)
                .background(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
