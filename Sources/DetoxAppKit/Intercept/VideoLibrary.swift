import Foundation

/// The user's folder of videos and photos shown when they reach for something blocked.
public enum MediaLibrary {
    public static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    public static let photoExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff"]

    private static func files(in folder: URL, _ exts: Set<String>) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles])) ?? []
        return items.filter { exts.contains($0.pathExtension.lowercased()) }
    }

    public static func videos(in folder: URL) -> [URL] { files(in: folder, videoExtensions) }
    public static func photos(in folder: URL) -> [URL] { files(in: folder, photoExtensions) }

    /// Copies videos and photos into the folder, never overwriting ("clip 2.mp4"). Returns how many were added.
    @discardableResult
    public static func add(_ urls: [URL], to folder: URL) -> Int {
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        var added = 0
        for url in urls where videoExtensions.union(photoExtensions).contains(url.pathExtension.lowercased()) {
            let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
            var dest = folder.appendingPathComponent(url.lastPathComponent)
            var n = 2
            while fm.fileExists(atPath: dest.path) {
                dest = folder.appendingPathComponent("\(base) \(n).\(ext)")
                n += 1
            }
            if (try? fm.copyItem(at: url, to: dest)) != nil { added += 1 }
        }
        return added
    }
}

/// Kept for callers that only want videos.
public enum VideoLibrary {
    public static func videos(in folder: URL) -> [URL] { MediaLibrary.videos(in: folder) }
    public static func randomVideo(in folder: URL) -> URL? { videos(in: folder).randomElement() }
}

/// Each attempt picks at random among what exists: a video, a photo with a phrase, or the breathing pause.
public enum InterceptPicker {
    public enum Kind: Hashable { case video, photo, calm }

    public static func kinds(hasVideos: Bool, hasPhotos: Bool) -> [Kind] {
        (hasVideos ? [.video] : []) + (hasPhotos ? [.photo] : []) + [.calm]
    }

    public static func pick<R: RandomNumberGenerator>(hasVideos: Bool, hasPhotos: Bool, using rng: inout R) -> Kind {
        kinds(hasVideos: hasVideos, hasPhotos: hasPhotos).randomElement(using: &rng)!
    }
}
