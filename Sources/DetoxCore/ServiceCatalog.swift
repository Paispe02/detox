import Foundation

public struct ServiceDefinition: Sendable {
    public let id: ServiceID
    public let displayName: String
    /// Domains the user types or visits; used to decide the intercept screen without Automation.
    public let primaryDomains: [String]
    /// Hosts exclusive to the service (APIs, CDNs). Never shared infrastructure.
    public let secondaryDomains: [String]
    public let appBundleIDs: [String]
}

public enum ServiceCatalog {
    public static let all: [ServiceDefinition] = [
        ServiceDefinition(
            id: .instagram, displayName: "Instagram",
            primaryDomains: ["instagram.com", "www.instagram.com"],
            secondaryDomains: ["i.instagram.com", "graph.instagram.com", "api.instagram.com", "help.instagram.com",
                               "about.instagram.com", "l.instagram.com", "cdninstagram.com",
                               "static.cdninstagram.com", "scontent.cdninstagram.com"],
            appBundleIDs: []),
        ServiceDefinition(
            id: .youtube, displayName: "YouTube",
            primaryDomains: ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"],
            secondaryDomains: ["music.youtube.com", "studio.youtube.com", "tv.youtube.com", "kids.youtube.com",
                               "youtube-nocookie.com", "www.youtube-nocookie.com", "youtubei.googleapis.com",
                               "youtube.googleapis.com", "i.ytimg.com", "s.ytimg.com", "i9.ytimg.com", "ytimg.com",
                               "yt3.ggpht.com", "redirector.googlevideo.com"],
            appBundleIDs: []),
        ServiceDefinition(
            id: .tiktok, displayName: "TikTok",
            primaryDomains: ["tiktok.com", "www.tiktok.com"],
            secondaryDomains: ["m.tiktok.com", "vm.tiktok.com", "vt.tiktok.com", "webcast.tiktok.com",
                               "tiktokcdn.com", "tiktokv.com", "byteoversea.com", "ibytedtos.com"],
            appBundleIDs: []),
        ServiceDefinition(
            id: .x, displayName: "X (Twitter)",
            primaryDomains: ["x.com", "www.x.com", "twitter.com", "www.twitter.com"],
            secondaryDomains: ["mobile.twitter.com", "mobile.x.com", "api.twitter.com", "api.x.com",
                               "abs.twimg.com", "pbs.twimg.com", "video.twimg.com", "twimg.com", "t.co"],
            appBundleIDs: []),
        ServiceDefinition(
            id: .facebook, displayName: "Facebook",
            primaryDomains: ["facebook.com", "www.facebook.com", "m.facebook.com"],
            secondaryDomains: ["web.facebook.com", "mbasic.facebook.com", "fb.com", "www.fb.com", "fb.me",
                               "messenger.com", "www.messenger.com", "static.xx.fbcdn.net", "fbcdn.net",
                               "connect.facebook.net", "facebook.net"],
            appBundleIDs: ["com.facebook.archon"]),
        ServiceDefinition(
            id: .reddit, displayName: "Reddit",
            primaryDomains: ["reddit.com", "www.reddit.com", "old.reddit.com"],
            secondaryDomains: ["new.reddit.com", "np.reddit.com", "i.reddit.com", "oauth.reddit.com",
                               "gql.reddit.com", "redd.it", "i.redd.it", "v.redd.it", "preview.redd.it",
                               "redditmedia.com", "www.redditmedia.com", "redditstatic.com", "www.redditstatic.com"],
            appBundleIDs: []),
        ServiceDefinition(
            id: .whatsapp, displayName: "WhatsApp",
            primaryDomains: ["web.whatsapp.com", "whatsapp.com", "www.whatsapp.com"],
            secondaryDomains: ["wa.me", "api.whatsapp.com", "w1.web.whatsapp.com", "w2.web.whatsapp.com",
                               "w3.web.whatsapp.com", "w4.web.whatsapp.com", "w5.web.whatsapp.com",
                               "w6.web.whatsapp.com", "w7.web.whatsapp.com", "w8.web.whatsapp.com",
                               "static.whatsapp.net", "mmg.whatsapp.net", "pps.whatsapp.net", "g.whatsapp.net",
                               "media.whatsapp.net", "whatsapp.net"],
            appBundleIDs: ["net.whatsapp.WhatsApp"]),
    ]

    public static func definition(_ id: ServiceID) -> ServiceDefinition {
        all.first { $0.id == id }!
    }
}
