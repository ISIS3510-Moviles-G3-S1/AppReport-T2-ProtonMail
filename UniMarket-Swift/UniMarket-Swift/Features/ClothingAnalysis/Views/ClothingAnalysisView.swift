//
//  ClothingAnalysisView.swift
//  UniMarket-Swift
//
//  Created by AI Assistant on 17/03/26.
//

import SwiftUI
import PhotosUI

struct ClothingAnalysisView: View {
    @StateObject private var viewModel = ClothingAnalysisViewModel()
    @State private var showImagePicker = false
    @State private var imagePickerSource: ImageSourceType = .camera
    
    enum ImageSourceType {
        case camera
        case photoLibrary
    }
    
    var body: some View {
        ZStack {
            if viewModel.isAnalyzing {
                LoadingAnalysisView()
            } else if viewModel.hasAnalysisResults {
                analysisResultsView
            } else if viewModel.hasError {
                errorView
            } else {
                initialView
            }
        }
        .navigationTitle("Clothing Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Initial State View
    private var initialView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Illustration
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.accent)
            
            VStack(spacing: 8) {
                Text("Analyze Your Item")
                    .font(.poppinsSemiBold(24))
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Get AI-powered tags for your clothing listing")
                    .font(.poppinsRegular(14))
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                // Camera button
                Button(action: {
                    imagePickerSource = .camera
                    showImagePicker = true
                }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Take a Photo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .foregroundColor(.white)
                    .font(.poppinsSemiBold(16))
                    .cornerRadius(12)
                }
                
                // Photo library button
                Button(action: {
                    imagePickerSource = .photoLibrary
                    showImagePicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Library")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.background)
                    .foregroundColor(AppTheme.accent)
                    .font(.poppinsSemiBold(16))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.accent, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                isPresented: $showImagePicker,
                image: $viewModel.selectedImage,
                sourceType: imagePickerSource == .camera ? .camera : .photoLibrary,
                onImageSelected: { image in
                    viewModel.analyzeImage(image)
                }
            )
        }
    }
    
    // MARK: - Analysis Results View
    private var analysisResultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with completion status
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.accent)
                        
                        Text("Analysis Complete")
                            .font(.poppinsSemiBold(16))
                            .foregroundColor(AppTheme.primaryText)
                        
                        Spacer()
                        
                        Text("\(viewModel.processingTimeMs)ms")
                            .font(.poppinsRegular(12))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Main category
                if let mainCategory = viewModel.mainCategoryTag {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Item Type")
                            .font(.poppinsSemiBold(14))
                            .foregroundColor(AppTheme.secondaryText)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            Text(mainCategory.name)
                                .font(.poppinsBold(32))
                                .foregroundColor(AppTheme.accent)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Confidence")
                                    .font(.poppinsRegular(12))
                                    .foregroundColor(AppTheme.secondaryText)
                                
                                Text("\(mainCategory.confidencePercentage)%")
                                    .font(.poppinsSemiBold(18))
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Colors
                if !viewModel.colorTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colors")
                            .font(.poppinsSemiBold(14))
                            .foregroundColor(AppTheme.secondaryText)
                            .textCase(.uppercase)
                        
                        VStack(spacing: 8) {
                            ForEach(viewModel.colorTags) { tag in
                                TagChipView(
                                    tag: tag,
                                    onRemove: viewModel.removeTag(withId:)
                                )
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.accentAlt.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Style
                if !viewModel.styleTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Style")
                            .font(.poppinsSemiBold(14))
                            .foregroundColor(AppTheme.secondaryText)
                            .textCase(.uppercase)
                        
                        VStack(spacing: 8) {
                            ForEach(viewModel.styleTags) { tag in
                                TagChipView(
                                    tag: tag,
                                    onRemove: viewModel.removeTag(withId:)
                                )
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Pattern
                if !viewModel.patternTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pattern")
                            .font(.poppinsSemiBold(14))
                            .foregroundColor(AppTheme.secondaryText)
                            .textCase(.uppercase)
                        
                        VStack(spacing: 8) {
                            ForEach(viewModel.patternTags) { tag in
                                TagChipView(
                                    tag: tag,
                                    onRemove: viewModel.removeTag(withId:)
                                )
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Information box
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.blue)
                        
                        Text("You can edit or remove tags before creating your listing")
                            .font(.poppinsRegular(12))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.logListingCreationStart()
                        // TODO: Navigate to create listing screen with tags
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Listing")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accent)
                        .foregroundColor(.white)
                        .font(.poppinsSemiBold(16))
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        imagePickerSource = .camera
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Analyze Another Item")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.background)
                        .foregroundColor(AppTheme.accent)
                        .font(.poppinsSemiBold(16))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.accent, lineWidth: 2)
                        )
                    }
                    .onAppear {
                        viewModel.logAnalyticsEvent()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .padding(.vertical, 16)
        }
        .backgroundColor(AppTheme.background)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                isPresented: $showImagePicker,
                image: $viewModel.selectedImage,
                sourceType: imagePickerSource == .camera ? .camera : .photoLibrary,
                onImageSelected: { image in
                    viewModel.analyzeImage(image)
                }
            )
        }
    }
    
    // MARK: - Error View
    private var errorView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color.red)
            
            VStack(spacing: 8) {
                Text("Analysis Failed")
                    .font(.poppinsSemiBold(20))
                    .foregroundColor(AppTheme.primaryText)
                
                Text(viewModel.errorMessage ?? "An unknown error occurred")
                    .font(.poppinsRegular(14))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    viewModel.retryAnalysis()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .foregroundColor(.white)
                    .font(.poppinsSemiBold(16))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    viewModel.clearResults()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Start Over")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.background)
                    .foregroundColor(AppTheme.accent)
                    .font(.poppinsSemiBold(16))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.accent, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, image: $image, onImageSelected: onImageSelected)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        @Binding var isPresented: Bool
        @Binding var image: UIImage?
        var onImageSelected: (UIImage) -> Void
        
        init(isPresented: Binding<Bool>, image: Binding<UIImage?>, onImageSelected: @escaping (UIImage) -> Void) {
            _isPresented = isPresented
            _image = image
            self.onImageSelected = onImageSelected
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                image = selectedImage
                onImageSelected(selectedImage)
            }
            isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isPresented = false
        }
    }
}

// MARK: - Helper Extensions
extension View {
    func backgroundColor(_ color: Color) -> some View {
        background(color)
    }
}

#Preview {
    NavigationStack {
        ClothingAnalysisView()
    }
}
