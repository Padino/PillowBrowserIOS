import Foundation

enum UserAgentType: String, CaseIterable {
    case `default` = "default"
    case desktop = "desktop"
    case mobile = "mobile"
    case chrome = "chrome"
    case safari = "safari"
    case firefox = "firefox"
    case edge = "edge"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .desktop:
            return "Desktop"
        case .mobile:
            return "Mobile"
        case .chrome:
            return "Chrome"
        case .safari:
            return "Safari"
        case .firefox:
            return "Firefox"
        case .edge:
            return "Microsoft Edge"
        case .custom:
            return "Custom"
        }
    }
    
    var userAgentString: String {
        switch self {
        case .default:
            return ""  // Use device default
        case .desktop:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
        case .mobile:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        case .chrome:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36"
        case .safari:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
        case .firefox:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:95.0) Gecko/20100101 Firefox/95.0"
        case .edge:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36 Edg/96.0.1054.62"
        case .custom:
            return ""  // Should be set separately
        }
    }
} 