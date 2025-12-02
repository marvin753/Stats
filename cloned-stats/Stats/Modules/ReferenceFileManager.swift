import Cocoa
import UniformTypeIdentifiers

/// Manages reference PDF file selection and security-scoped bookmark storage
/// Implements Safeguard 4: App Restart Bookmark Restoration
class ReferenceFileManager {

    // MARK: - Singleton
    static let shared = ReferenceFileManager()

    // MARK: - Constants
    private let bookmarkKey = "referencePDFBookmark"
    private let filePathKey = "referencePDFPath"
    private let fileIdKey = "referencePDFFileId"

    // MARK: - State
    private var cachedURL: URL?
    private var isAccessingSecurityScopedResource: Bool = false

    /// The OpenAI file_id for the uploaded reference
    var uploadedFileId: String? {
        get { UserDefaults.standard.string(forKey: fileIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: fileIdKey) }
    }

    // MARK: - Public Properties

    /// Check if a reference file is configured
    var hasReferenceFile: Bool {
        return cachedURL != nil || UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    /// Get the current file path (display only)
    var currentFilePath: String? {
        if let url = cachedURL {
            return url.path
        }
        return UserDefaults.standard.string(forKey: filePathKey)
    }

    /// Get the filename only
    var currentFileName: String? {
        if let url = cachedURL {
            return url.lastPathComponent
        }
        if let path = UserDefaults.standard.string(forKey: filePathKey) {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return nil
    }

    // MARK: - Initialization

    private init() {
        print("[ReferenceFileManager] Initializing...")
        restoreBookmarkOnLaunch()
    }

    // MARK: - Safeguard 4: Bookmark Restoration

    /// Restore bookmark on app launch
    private func restoreBookmarkOnLaunch() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            print("[ReferenceFileManager] No saved bookmark found")
            return
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                print("⚠️ [ReferenceFileManager] Bookmark is stale - attempting to recreate")
                // Try to recreate the bookmark if we can still access the file
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }

                    do {
                        let newBookmark = try url.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        UserDefaults.standard.set(newBookmark, forKey: bookmarkKey)
                        print("✅ [ReferenceFileManager] Stale bookmark recreated")
                    } catch {
                        print("❌ [ReferenceFileManager] Failed to recreate stale bookmark: \(error)")
                    }
                }
            }

            // Verify file still exists
            if !FileManager.default.fileExists(atPath: url.path) {
                print("⚠️ [ReferenceFileManager] Referenced file no longer exists at: \(url.path)")
                clearReferenceFile()
                return
            }

            cachedURL = url
            UserDefaults.standard.set(url.path, forKey: filePathKey)
            print("✅ [ReferenceFileManager] Bookmark restored: \(url.lastPathComponent)")

        } catch {
            print("❌ [ReferenceFileManager] Failed to restore bookmark: \(error)")
            clearReferenceFile()
        }
    }

    // MARK: - File Selection

    /// Open file picker to select a reference PDF
    func selectReferenceFile(completion: @escaping (URL?) -> Void) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            if #available(macOS 11.0, *) {
                panel.allowedContentTypes = [.pdf]
            } else {
                panel.allowedFileTypes = ["pdf"]
            }
            panel.message = "Select a PDF document to use as reference"
            panel.prompt = "Select PDF"

            panel.begin { [weak self] response in
                guard response == .OK, let url = panel.url else {
                    print("[ReferenceFileManager] File selection cancelled")
                    completion(nil)
                    return
                }

                self?.saveBookmark(for: url)
                completion(url)
            }
        }
    }

    // MARK: - Bookmark Management

    /// Save security-scoped bookmark for the selected file
    private func saveBookmark(for url: URL) {
        do {
            // Start accessing to create bookmark
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ [ReferenceFileManager] Cannot access security-scoped resource")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Create security-scoped bookmark
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Save to UserDefaults
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            UserDefaults.standard.set(url.path, forKey: filePathKey)

            // Update cached URL
            cachedURL = url

            print("✅ [ReferenceFileManager] Bookmark saved for: \(url.lastPathComponent)")

        } catch {
            print("❌ [ReferenceFileManager] Failed to create bookmark: \(error)")
        }
    }

    // MARK: - File Access

    /// Resolve the bookmark and return URL with security scope access started
    /// IMPORTANT: Caller must call stopAccess(url) when done
    func resolveBookmark() -> URL? {
        // If we have a cached URL, try to use it
        if let cached = cachedURL {
            if cached.startAccessingSecurityScopedResource() {
                isAccessingSecurityScopedResource = true
                return cached
            }
        }

        // Otherwise resolve from bookmark data
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            print("⚠️ [ReferenceFileManager] No bookmark data found")
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard url.startAccessingSecurityScopedResource() else {
                print("❌ [ReferenceFileManager] Cannot start accessing security-scoped resource")
                return nil
            }

            isAccessingSecurityScopedResource = true
            cachedURL = url

            if isStale {
                // Recreate bookmark
                print("⚠️ [ReferenceFileManager] Bookmark was stale, recreating...")
                saveBookmark(for: url)
            }

            return url

        } catch {
            print("❌ [ReferenceFileManager] Failed to resolve bookmark: \(error)")
            return nil
        }
    }

    /// Stop accessing the security-scoped resource
    func stopAccess(_ url: URL) {
        if isAccessingSecurityScopedResource {
            url.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
        }
    }

    /// Get file data for upload (handles security-scoped access)
    func getFileDataForUpload() -> (data: Data, filename: String)? {
        guard let url = resolveBookmark() else {
            print("❌ [ReferenceFileManager] Cannot resolve bookmark for upload")
            return nil
        }
        defer { stopAccess(url) }

        do {
            let data = try Data(contentsOf: url)
            return (data: data, filename: url.lastPathComponent)
        } catch {
            print("❌ [ReferenceFileManager] Failed to read file data: \(error)")
            return nil
        }
    }

    // MARK: - Cleanup

    /// Clear the stored reference file
    func clearReferenceFile() {
        // Stop any active access
        if let url = cachedURL, isAccessingSecurityScopedResource {
            url.stopAccessingSecurityScopedResource()
        }

        // Clear stored data
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: filePathKey)
        UserDefaults.standard.removeObject(forKey: fileIdKey)

        // Clear state
        cachedURL = nil
        isAccessingSecurityScopedResource = false
        uploadedFileId = nil

        print("✅ [ReferenceFileManager] Reference file cleared")
    }

    /// Verify the current reference file is still valid
    func verifyReferenceFile() -> Bool {
        guard let url = resolveBookmark() else {
            return false
        }
        defer { stopAccess(url) }

        return FileManager.default.fileExists(atPath: url.path)
    }
}
