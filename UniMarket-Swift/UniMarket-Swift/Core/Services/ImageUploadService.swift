import UIKit
import FirebaseStorage
import FirebaseAuth

struct ImageUploadService {

    // MARK: - Upload profile picture
    static func uploadProfilePic(_ image: UIImage) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ImageUploadError.notAuthenticated
        }
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw ImageUploadError.compressionFailed
        }

        let ref = Storage.storage().reference().child("avatars/\(uid)/profile.jpg")

        do {
            _ = try await ref.putDataAsync(imageData)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            print("DEBUG: Failed to upload profile image with error \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Upload listing image
    static func uploadListingImage(_ image: UIImage, listingId: String, index: Int) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ImageUploadError.notAuthenticated
        }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ImageUploadError.compressionFailed
        }

        let ref = Storage.storage().reference().child("listings/\(uid)/\(listingId)/image_\(index).jpg")

        do {
            _ = try await ref.putDataAsync(imageData)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            print("DEBUG: Failed to upload listing image with error \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Delete image
    static func deleteImage(at urlString: String) async throws {
        let ref = Storage.storage().reference(forURL: urlString)
        try await ref.delete()
    }
}

enum ImageUploadError: LocalizedError {
    case notAuthenticated
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to upload images."
        case .compressionFailed:
            return "Failed to process image."
        }
    }
}
