import Foundation

public enum HTTPDate {
    public static func parse(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f.date(from: s)
    }
}

public protocol NetworkTimeFetching {
    func fetch(_ completion: @escaping (Date?) -> Void)
}

/// Reads the `Date` header of a HEAD request to apple.com.
public final class AppleNetworkTime: NetworkTimeFetching {
    private let url = URL(string: "https://www.apple.com")!

    public init() {}

    public func fetch(_ completion: @escaping (Date?) -> Void) {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        req.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: req) { _, response, _ in
            let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Date")
            completion(header.flatMap(HTTPDate.parse))
        }.resume()
    }
}
