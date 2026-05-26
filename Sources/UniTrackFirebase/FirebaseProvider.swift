// FirebaseProvider — forwards every UniTrack event to Firebase Analytics.
//
// Prerequisites (standard Firebase iOS setup, done by the app):
//   • GoogleService-Info.plist added to the app target.
//
//   UniTrack.addProvider(FirebaseProvider())
//   UniTrack.initialize(apiKey: ...)
//
// Firebase imposes strict naming rules (event/param names ≤40 chars,
// alphanumeric + underscore, start with a letter; values String/number), so
// names and parameters are sanitized.

import Foundation
import UniTrack
#if canImport(FirebaseAnalytics)
import FirebaseCore
import FirebaseAnalytics

public final class FirebaseProvider: AnalyticsProvider {

    private let portalEndpoint: String?
    private let portalApiKey: String?

    /// portalEndpoint + portalApiKey: optional. When both are set, every event
    /// forwarded to Firebase is ALSO copied to the UniTrack portal tagged
    /// provider=firebase, so the portal can show what went to Firebase.
    public init(portalEndpoint: String? = nil, portalApiKey: String? = nil) {
        self.portalEndpoint = portalEndpoint
        self.portalApiKey = portalApiKey
    }

    public func initializeProvider() {
        // initializeApp reads GoogleService-Info.plist. Guard against the app
        // having already configured Firebase.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        NSLog("[UniTrackFirebase] Firebase Analytics ready")
    }

    public func track(_ name: String, _ properties: [String: Any]) {
        Analytics.logEvent(sanitizeName(name), parameters: sanitizeParams(properties))
        mirrorToPortal(name, properties)
    }

    // Fire-and-forget copy to the portal, tagged provider=firebase.
    private func mirrorToPortal(_ name: String, _ properties: [String: Any]) {
        guard let ep = portalEndpoint, let key = portalApiKey,
              !ep.isEmpty, !key.isEmpty,
              let url = URL(string: ep + (ep.contains("?") ? "&" : "?") + "provider=firebase")
        else { return }
        let payload: [String: Any] = [
            "event_id": "\(Int(Date().timeIntervalSince1970 * 1_000_000))_\(name)",
            "event_name": name,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "properties": properties,
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        URLSession.shared.dataTask(with: req).resume()
    }

    public func setUser(_ userId: String?, _ traits: [String: Any]) {
        Analytics.setUserID(userId)
        for (k, v) in traits {
            Analytics.setUserProperty(stringify(v), forName: sanitizeName(k))
        }
    }

    public func setScreen(_ name: String) {
        Analytics.logEvent(AnalyticsEventScreenView,
                           parameters: [AnalyticsParameterScreenName: name])
    }

    // --- Firebase naming/value constraints ----------------------------------

    private func sanitizeName(_ name: String) -> String {
        var s = name.map { $0.isLetter || $0.isNumber || $0 == "_" ? $0 : "_" }
                    .reduce("") { $0 + String($1) }
        if let first = s.first, !first.isLetter { s = "e_" + s }
        if s.count > 40 { s = String(s.prefix(40)) }
        return s
    }

    private func sanitizeParams(_ props: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in props {
            let key = sanitizeName(k)
            if v is NSNumber || v is String {
                if let str = v as? String, str.count > 100 {
                    out[key] = String(str.prefix(100))
                } else {
                    out[key] = v
                }
            } else {
                out[key] = stringify(v)
            }
        }
        return out
    }

    private func stringify(_ v: Any) -> String {
        if let s = v as? String { return s }
        return String(describing: v)
    }
}
#else
public final class FirebaseProvider: AnalyticsProvider {
    public init() {}
    public func initializeProvider() {
        NSLog("[UniTrackFirebase] FirebaseAnalytics not available")
    }
    public func track(_ name: String, _ properties: [String: Any]) {}
    public func setUser(_ userId: String?, _ traits: [String: Any]) {}
    public func setScreen(_ name: String) {}
}
#endif
