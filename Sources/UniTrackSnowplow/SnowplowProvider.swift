// SnowplowProvider — forwards every UniTrack event to a Snowplow collector.
//
//   UniTrack.addProvider(SnowplowProvider(
//       endpoint: "https://collector.example.com",
//       appId: "701",
//       userContext: ["username": "duc"],
//       userContextSchema: "iglu:vn.fpt.ftel.snowplow/user_context/jsonschema/1-0-0",
//       schemas: ["add_to_cart": "iglu:com.acme/add_to_cart/jsonschema/1-0-0"]))
//   UniTrack.initialize(apiKey: ...)
//
// Events with a matching `schemas` entry → self-describing events; others →
// Structured events (category "unitrack"). The optional user-context entity is
// attached to every event. Uses the Snowplow iOS tracker SDK (SnowplowTracker).

import Foundation
import UniTrack
#if canImport(SnowplowTracker)
import SnowplowTracker

public final class SnowplowProvider: AnalyticsProvider {

    private let endpoint: String
    private let appId: String
    private let namespace: String
    private var userContext: [String: Any]?
    private let userContextSchema: String?
    private let schemas: [String: String]

    private var tracker: TrackerController?

    public init(endpoint: String,
                appId: String,
                namespace: String = "UniTrack",
                userContext: [String: Any]? = nil,
                userContextSchema: String? = nil,
                schemas: [String: String] = [:]) {
        self.endpoint = endpoint
        self.appId = appId
        self.namespace = namespace
        self.userContext = userContext
        self.userContextSchema = userContextSchema
        self.schemas = schemas
    }

    public func initializeProvider() {
        guard !endpoint.isEmpty else {
            NSLog("[UniTrackSnowplow] empty endpoint — provider disabled")
            return
        }
        let network = NetworkConfiguration(endpoint: endpoint, method: .post)
        let trackerConfig = TrackerConfiguration()
            .appId(appId)
            .base64Encoding(true)
            .platformContext(true)
            .applicationContext(true)
            .sessionContext(true)
            .screenContext(true)
            .lifecycleAutotracking(true)
        tracker = Snowplow.createTracker(namespace: namespace,
                                         network: network,
                                         configurations: [trackerConfig])
        NSLog("[UniTrackSnowplow] tracker ready (\(endpoint), appId=\(appId))")
    }

    public func updateUserContext(_ ctx: [String: Any]) { userContext = ctx }

    private func entities() -> [SelfDescribingJson] {
        guard let userContext = userContext, let schema = userContextSchema else {
            return []
        }
        return [SelfDescribingJson(schema: schema, andData: userContext)]
    }

    public func track(_ name: String, _ properties: [String: Any]) {
        guard let tracker = tracker else { return }
        if let schema = schemas[name] {
            // Self-describing event for mapped names.
            let sd = SelfDescribing(schema: schema, payload: properties)
            _ = sd.entities(entities())
            tracker.track(sd)
        } else {
            // Structured event for everything else.
            let structured = Structured(category: "unitrack", action: name)
            structured.label =
                (properties["screen"] ?? properties["screen_name"]) as? String
            structured.property =
                (properties["element_key"] ?? properties["state"]) as? String
            _ = structured.entities(entities())
            tracker.track(structured)
        }
    }

    public func setUser(_ userId: String?, _ traits: [String: Any]) {
        tracker?.subject?.userId = userId
        if !traits.isEmpty, var ctx = userContext {
            traits.forEach { ctx[$0.key] = $0.value }
            userContext = ctx
        }
    }

    public func setScreen(_ name: String) {
        guard let tracker = tracker else { return }
        let sv = ScreenView(name: name)
        _ = sv.entities(entities())
        tracker.track(sv)
    }
}
#else
// SnowplowTracker not linked — provide a stub so the file still compiles if the
// pod is present without its dependency (shouldn't happen in normal use).
public final class SnowplowProvider: AnalyticsProvider {
    public init(endpoint: String, appId: String, namespace: String = "UniTrack",
                userContext: [String: Any]? = nil, userContextSchema: String? = nil,
                schemas: [String: String] = [:]) {}
    public func initializeProvider() {
        NSLog("[UniTrackSnowplow] SnowplowTracker not available")
    }
    public func track(_ name: String, _ properties: [String: Any]) {}
    public func setUser(_ userId: String?, _ traits: [String: Any]) {}
    public func setScreen(_ name: String) {}
}
#endif
