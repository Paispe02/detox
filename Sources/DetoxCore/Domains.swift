import Foundation

public enum DomainNormalizer {
    private static let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789.-")

    /// Turns what a user types or pastes ("https://www.Instagram.com/x?y") into a bare host, or nil.
    public static func normalize(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let r = s.range(of: "://") { s = String(s[r.upperBound...]) }
        if let cut = s.firstIndex(where: { "/?#".contains($0) }) { s = String(s[..<cut]) }
        if let colon = s.firstIndex(of: ":") { s = String(s[..<colon]) }
        while s.hasSuffix(".") { s.removeLast() }
        guard !s.isEmpty, s.allSatisfy({ allowed.contains($0) }), s.contains(".") else { return nil }
        let labels = s.split(separator: ".", omittingEmptySubsequences: false)
        for l in labels where l.isEmpty || l.hasPrefix("-") || l.hasSuffix("-") || l.count > 63 {
            return nil
        }
        return s
    }
}

public enum DomainExpansion {
    /// The host plus its www/apex twin when the host has exactly two labels (or is www.<two labels>).
    public static func variants(of host: String) -> [String] {
        if host.hasPrefix("www.") { return [host, String(host.dropFirst(4))] }
        if host.split(separator: ".").count == 2 { return [host, "www." + host] }
        return [host]
    }
}
