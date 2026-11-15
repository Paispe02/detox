import Foundation
import Testing
@testable import DetoxAppKit

private func tempDir() throws -> URL {
    let d = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("media-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

@Test func libraryListsPhotosAndVideosSeparately() throws {
    let d = try tempDir()
    for f in ["a.mp4", "b.JPG", "c.heic", "d.png", "e.txt", ".x.jpg"] { try Data().write(to: d.appendingPathComponent(f)) }
    #expect(MediaLibrary.videos(in: d).map(\.lastPathComponent) == ["a.mp4"])
    #expect(MediaLibrary.photos(in: d).map(\.lastPathComponent).sorted() == ["b.JPG", "c.heic", "d.png"])
}

@Test func pickerOnlyOffersWhatExists() {
    #expect(InterceptPicker.kinds(hasVideos: false, hasPhotos: false) == [.calm])
    #expect(InterceptPicker.kinds(hasVideos: true, hasPhotos: false) == [.video, .calm])
    #expect(InterceptPicker.kinds(hasVideos: true, hasPhotos: true) == [.video, .photo, .calm])
}

@Test func pickerAlternatesAcrossKinds() {
    var rng = SystemRandomNumberGenerator()
    let seen = Set((0..<200).map { _ in InterceptPicker.pick(hasVideos: true, hasPhotos: true, using: &rng) })
    #expect(seen == [.video, .photo, .calm])
}

@Test func addCopiesOnlyMediaAndAvoidsOverwriting() throws {
    let src = try tempDir(), dst = try tempDir()
    try Data("v".utf8).write(to: src.appendingPathComponent("clip.mp4"))
    try Data("t".utf8).write(to: src.appendingPathComponent("notes.txt"))
    try Data("old".utf8).write(to: dst.appendingPathComponent("clip.mp4"))
    let added = MediaLibrary.add([src.appendingPathComponent("clip.mp4"), src.appendingPathComponent("notes.txt")], to: dst)
    #expect(added == 1)
    #expect(try Data(contentsOf: dst.appendingPathComponent("clip.mp4")) == Data("old".utf8))
    #expect(FileManager.default.fileExists(atPath: dst.appendingPathComponent("clip 2.mp4").path))
    #expect(!FileManager.default.fileExists(atPath: dst.appendingPathComponent("notes.txt").path))
}
