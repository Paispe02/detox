import Foundation

public enum VideoLibrary {
    static let extensions: Set<String> = ["mp4", "mov", "m4v"]

    public static func videos(in folder: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles])) ?? []
        return items.filter { extensions.contains($0.pathExtension.lowercased()) }
    }

    public static func randomVideo(in folder: URL) -> URL? {
        videos(in: folder).randomElement()
    }
}
