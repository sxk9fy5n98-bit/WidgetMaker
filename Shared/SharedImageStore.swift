import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum SharedImageStore {
    /// Widget memory budgets are tight — keep backgrounds reasonably small.
    private static let maxPixelDimension: CGFloat = 1200
    private static let jpegQuality: CGFloat = 0.82

    private static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.suiteName
        )
    }

    private static var imagesDirectoryURL: URL? {
        guard let containerURL else { return nil }
        return containerURL.appendingPathComponent(
            AppGroupConstants.imagesDirectoryName,
            isDirectory: true
        )
    }

    /// Writes image data into the App Group container and returns the stored filename.
    @discardableResult
    static func saveImageData(_ data: Data, preferredFileName: String? = nil) throws -> String {
        guard let imagesDirectoryURL else {
            throw SharedImageStoreError.containerUnavailable
        }

        try FileManager.default.createDirectory(
            at: imagesDirectoryURL,
            withIntermediateDirectories: true
        )

        let prepared = preparedImageData(from: data)
        let fileName = preferredFileName ?? "\(UUID().uuidString).jpg"
        let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)
        try prepared.write(to: fileURL, options: .atomic)
        return fileName
    }

    /// Resolves a filename to a file URL inside the App Group images directory.
    static func imageURL(for fileName: String) -> URL? {
        guard let imagesDirectoryURL else { return nil }
        let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return fileURL
    }

    static func loadImageData(fileName: String) -> Data? {
        guard let url = imageURL(for: fileName) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func deleteImage(fileName: String) {
        guard let url = imageURL(for: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func preparedImageData(from data: Data) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let resized = resizedImage(image, maxDimension: maxPixelDimension)
        return resized.jpegData(compressionQuality: jpegQuality) ?? data
        #else
        return data
        #endif
    }

    #if canImport(UIKit)
    private static func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif
}

enum SharedImageStoreError: LocalizedError {
    case containerUnavailable

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return L10n.sharedStorageUnavailableShort
        }
    }
}
