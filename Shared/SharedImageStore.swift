import Foundation

enum SharedImageStore {
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

        let fileName = preferredFileName ?? "\(UUID().uuidString).jpg"
        let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
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
}

enum SharedImageStoreError: Error {
    case containerUnavailable
}
