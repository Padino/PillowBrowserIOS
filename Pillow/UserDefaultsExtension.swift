import Foundation

extension UserDefaults {
    private enum Keys {
        static let userAgentType = "user_agent_type"
        static let customUserAgent = "custom_user_agent"
        static let blockPopups = "block_popups"
        static let javascriptEnabled = "enable_javascript"
        static let defaultTabURL = "default_tab_url"
        static let searchEngine = "search_engine"
    }
    
    var userAgentType: UserAgentType {
        get {
            if let value = string(forKey: Keys.userAgentType),
               let type = UserAgentType(rawValue: value) {
                return type
            }
            return .default
        }
        set {
            set(newValue.rawValue, forKey: Keys.userAgentType)
        }
    }
    
    var customUserAgent: String {
        get {
            return string(forKey: Keys.customUserAgent) ?? ""
        }
        set {
            set(newValue, forKey: Keys.customUserAgent)
        }
    }
    
    var blockPopups: Bool {
        get {
            return bool(forKey: Keys.blockPopups)
        }
        set {
            set(newValue, forKey: Keys.blockPopups)
        }
    }
    
    var javascriptEnabled: Bool {
        get {
            return bool(forKey: Keys.javascriptEnabled)
        }
        set {
            set(newValue, forKey: Keys.javascriptEnabled)
        }
    }
    
    static func registerDefaults() {
        let defaults: [String: Any] = [
            Keys.userAgentType: UserAgentType.default.rawValue,
            Keys.customUserAgent: "",
            Keys.blockPopups: true,
            Keys.javascriptEnabled: true,
            Keys.defaultTabURL: "https://www.google.com",
            Keys.searchEngine: SearchEngineType.google.rawValue
        ]
        
        UserDefaults.standard.register(defaults: defaults)
    }
} 