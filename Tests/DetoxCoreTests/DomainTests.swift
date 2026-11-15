import Foundation
import Testing
@testable import DetoxCore

@Test(arguments: [
    ("https://www.Instagram.com/explore?x=1", "www.instagram.com"),
    ("  reddit.com.  ", "reddit.com"),
    ("twitch.tv:443", "twitch.tv"),
    ("HTTP://News.YCombinator.com/", "news.ycombinator.com"),
    ("www.youtube.com/watch?v=1", "www.youtube.com"),
])
func normalizesPastedURLs(input: String, expected: String) {
    #expect(DomainNormalizer.normalize(input) == expected)
}

@Test(arguments: ["localhost", "not a domain", "a..b.com", "*.foo.com", "", "ñandú.com", "-bad.com"])
func rejectsInvalidDomains(input: String) {
    #expect(DomainNormalizer.normalize(input) == nil)
}

@Test func expansionTogglesWWW() {
    #expect(DomainExpansion.variants(of: "reddit.com") == ["reddit.com", "www.reddit.com"])
    #expect(DomainExpansion.variants(of: "www.reddit.com") == ["www.reddit.com", "reddit.com"])
    #expect(DomainExpansion.variants(of: "old.reddit.com") == ["old.reddit.com"])
}

@Test func catalogNeverIncludesSharedInfrastructure() {
    let forbidden: Set<String> = ["google.com", "www.google.com", "gstatic.com", "googleapis.com",
                                  "googleusercontent.com", "apple.com", "icloud.com"]
    for s in ServiceCatalog.all {
        let all = Set(s.primaryDomains + s.secondaryDomains)
        #expect(all.isDisjoint(with: forbidden), "\(s.id)")
        if s.id != .facebook {
            #expect(!all.contains { $0.hasSuffix("fbcdn.net") || $0.hasSuffix("facebook.net") }, "\(s.id)")
        }
    }
}

@Test func everyServiceHasItsPrimaryDomains() {
    let expected: [ServiceID: [String]] = [
        .instagram: ["instagram.com", "www.instagram.com"],
        .youtube: ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"],
        .tiktok: ["tiktok.com", "www.tiktok.com"],
        .x: ["x.com", "www.x.com", "twitter.com", "www.twitter.com"],
        .facebook: ["facebook.com", "www.facebook.com", "m.facebook.com"],
        .reddit: ["reddit.com", "www.reddit.com", "old.reddit.com"],
        .whatsapp: ["web.whatsapp.com", "whatsapp.com", "www.whatsapp.com"],
    ]
    for (id, domains) in expected {
        #expect(ServiceCatalog.definition(id).primaryDomains == domains)
    }
    #expect(ServiceCatalog.definition(.whatsapp).appBundleIDs == ["net.whatsapp.WhatsApp"])
    #expect(ServiceCatalog.all.count == ServiceID.allCases.count)
}
