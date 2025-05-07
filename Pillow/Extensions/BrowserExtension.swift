import Foundation
import WebKit
import SwiftUI

// Extension categories like in Safari
enum ExtensionCategory: String, CaseIterable {
    case contentBlocker = "Content Blocker"
    case webEnhancement = "Web Enhancement"
    case security = "Security"
    case privacy = "Privacy"
    case appearance = "Appearance"
    case media = "Media"
    case productivity = "Productivity"
    case shopping = "Shopping"
    case social = "Social"
    case developer = "Developer Tools"
    case other = "Other"
}

// Extension icon type
enum ExtensionIconType {
    case system(name: String)  // SF Symbol
    case image(name: String)   // Image asset
    case data(Data)            // Custom image data
}

// Extension activation state
enum ExtensionActivationState {
    case always              // Always active on all sites
    case allowlist([String]) // Only active on specified domains
    case blocklist([String]) // Active except on specified domains
    case custom              // Custom rule-based activation
}

// Extension event that can be observed
enum ExtensionEvent {
    case pageLoad(URL)
    case pageUnload(URL)
    case documentStart(URL)
    case documentEnd(URL)
    case contentBlocked(URL, URLRequest)
    case formSubmission(URL, [String: String])
    case actionButtonClicked
    case contextMenuActivated(URL, String?) // URL and selected text if any
}

// Main protocol that all extensions must conform to
protocol BrowserExtension {
    // Basic extension metadata
    var id: String { get }
    var name: String { get }
    var version: String { get }
    var description: String { get }
    var author: String { get }
    var isEnabled: Bool { get set }
    var website: URL? { get }
    var category: ExtensionCategory { get }
    var icon: ExtensionIconType { get }
    var safariCompatible: Bool { get }  // Indicates if this extension can work on Safari
    
    // Activation rules
    var activationState: ExtensionActivationState { get set }
    var isActive: Bool { get } // Computed property based on activation state
    
    // Permissions model
    var permissions: [ExtensionPermission] { get }
    
    // Extension capabilities
    var canInjectScripts: Bool { get }
    var canModifyRequests: Bool { get }
    var canModifyHeaders: Bool { get }
    var canAccessUserData: Bool { get }
    var canDisplayUIOverlay: Bool { get }
    var canIntegrateWithBrowserUI: Bool { get }
    
    // User interface integration
    var toolbarItem: ExtensionToolbarItem? { get }
    var contextMenuItems: [ExtensionContextMenuItem] { get }
    var settingsView: AnyView? { get }
    
    // Extension lifecycle methods
    func initialize()
    func cleanup()
    
    // Content modification methods
    func getScriptsToInject(for url: URL) -> [ExtensionScript]?
    func shouldBlockRequest(_ request: URLRequest) -> Bool
    func modifyRequest(_ request: URLRequest) -> URLRequest
    func modifyResponse(_ response: URLResponse, data: Data) -> Data
    
    // Event handling
    func handleEvent(_ event: ExtensionEvent)
    
    // Domain-specific methods
    func isActiveForDomain(_ domain: String) -> Bool
    
    // Browser UI integration
    func onToolbarItemTapped(webView: WKWebView?)
    func onContextMenuItemSelected(item: String, webView: WKWebView?)
}

// Extension permissions (like in Safari)
enum ExtensionPermission: String, CaseIterable, Identifiable {
    case readBrowsingHistory = "Read Browsing History"
    case readCurrentPage = "Read Current Page Contents"
    case modifyWebContent = "Modify Web Content"
    case blockContent = "Block Content"
    case accessBrowsingData = "Access Browsing Data"
    case accessCookies = "Access Cookies"
    case accessDownloads = "Access Downloads"
    case accessCamera = "Access Camera"
    case accessMicrophone = "Access Microphone"
    case accessLocation = "Access Location"
    case showNotifications = "Show Notifications"
    case accessClipboard = "Access Clipboard"
    case modifyHeaders = "Modify Request Headers"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .readBrowsingHistory:
            return "Access your browsing history"
        case .readCurrentPage:
            return "Read the content of webpages you visit"
        case .modifyWebContent:
            return "Change the content of webpages you visit"
        case .blockContent:
            return "Block content from loading on websites"
        case .accessBrowsingData:
            return "Access your browsing data including history and bookmarks"
        case .accessCookies:
            return "Access and modify cookies from websites"
        case .accessDownloads:
            return "Access your downloads and download history"
        case .accessCamera:
            return "Access your device's camera"
        case .accessMicrophone:
            return "Access your device's microphone"
        case .accessLocation:
            return "Access your device's location"
        case .showNotifications:
            return "Show notifications on your device"
        case .accessClipboard:
            return "Access your clipboard content"
        case .modifyHeaders:
            return "Modify request headers sent to websites"
        }
    }
    
    var icon: String {
        switch self {
        case .readBrowsingHistory: return "clock"
        case .readCurrentPage: return "doc.text"
        case .modifyWebContent: return "pencil"
        case .blockContent: return "shield"
        case .accessBrowsingData: return "folder"
        case .accessCookies: return "tray"
        case .accessDownloads: return "arrow.down.circle"
        case .accessCamera: return "camera"
        case .accessMicrophone: return "mic"
        case .accessLocation: return "location"
        case .showNotifications: return "bell"
        case .accessClipboard: return "doc.on.clipboard"
        case .modifyHeaders: return "arrow.left.arrow.right"
        }
    }
}

// Type of script to inject
enum ExtensionScriptInjectionTime {
    case atStart
    case atEnd
    case onDOMContentLoaded
    case onPageLoad
}

// Encapsulates script content and injection timing
struct ExtensionScript {
    let content: String
    let injectionTime: ExtensionScriptInjectionTime
    let forURL: URL?  // If nil, inject into all URLs
    
    init(content: String, injectionTime: ExtensionScriptInjectionTime = .onPageLoad, forURL: URL? = nil) {
        self.content = content
        self.injectionTime = injectionTime
        self.forURL = forURL
    }
}

// Browser toolbar item (like Safari's extension buttons)
struct ExtensionToolbarItem {
    let id: String
    let title: String
    let icon: ExtensionIconType
    let showLabel: Bool
    let badge: String?
    
    init(id: String, title: String, icon: ExtensionIconType, showLabel: Bool = false, badge: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.showLabel = showLabel
        self.badge = badge
    }
}

// Context menu items
struct ExtensionContextMenuItem {
    let id: String
    let title: String
    let icon: ExtensionIconType
    let requiresSelection: Bool
    
    init(id: String, title: String, icon: ExtensionIconType, requiresSelection: Bool = false) {
        self.id = id
        self.title = title
        self.icon = icon
        self.requiresSelection = requiresSelection
    }
}

// Default implementations
extension BrowserExtension {
    // Default implementation to make some methods optional
    var website: URL? { return nil }
    var category: ExtensionCategory { return .other }
    var safariCompatible: Bool { return false }
    var activationState: ExtensionActivationState { return .always }
    var isActive: Bool { return isEnabled }
    var toolbarItem: ExtensionToolbarItem? { return nil }
    var contextMenuItems: [ExtensionContextMenuItem] { return [] }
    var settingsView: AnyView? { return nil }
    var canDisplayUIOverlay: Bool { return false }
    var canIntegrateWithBrowserUI: Bool { return false }
    
    func initialize() {}
    func cleanup() {}
    func getScriptsToInject(for url: URL) -> [ExtensionScript]? { return nil }
    func shouldBlockRequest(_ request: URLRequest) -> Bool { return false }
    func modifyRequest(_ request: URLRequest) -> URLRequest { return request }
    func modifyResponse(_ response: URLResponse, data: Data) -> Data { return data }
    func handleEvent(_ event: ExtensionEvent) {}
    
    func isActiveForDomain(_ domain: String) -> Bool {
        guard isEnabled else { return false }
        
        switch activationState {
        case .always:
            return true
        case .allowlist(let domains):
            return domains.contains { domain.hasSuffix($0) }
        case .blocklist(let domains):
            return !domains.contains { domain.hasSuffix($0) }
        case .custom:
            // Default implementation for custom - subclasses should override this
            return true
        }
    }
    
    func onToolbarItemTapped(webView: WKWebView?) {}
    func onContextMenuItemSelected(item: String, webView: WKWebView?) {}
}

// Base class for extensions to make implementation easier
class BaseBrowserExtension: BrowserExtension {
    let id: String
    let name: String
    let version: String
    let description: String
    let author: String
    var isEnabled: Bool
    let category: ExtensionCategory
    let icon: ExtensionIconType
    let website: URL?
    let safariCompatible: Bool
    let permissions: [ExtensionPermission]
    
    let canInjectScripts: Bool
    let canModifyRequests: Bool
    let canModifyHeaders: Bool
    let canAccessUserData: Bool
    let canDisplayUIOverlay: Bool
    let canIntegrateWithBrowserUI: Bool
    
    var activationState: ExtensionActivationState = .always
    
    init(id: String, 
         name: String, 
         version: String, 
         description: String,
         author: String,
         icon: ExtensionIconType = .system(name: "puzzlepiece.extension"),
         isEnabled: Bool = true,
         category: ExtensionCategory = .other,
         website: URL? = nil,
         safariCompatible: Bool = false,
         permissions: [ExtensionPermission] = [],
         canInjectScripts: Bool = false,
         canModifyRequests: Bool = false,
         canModifyHeaders: Bool = false,
         canAccessUserData: Bool = false,
         canDisplayUIOverlay: Bool = false,
         canIntegrateWithBrowserUI: Bool = false,
         activationState: ExtensionActivationState = .always) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.isEnabled = isEnabled
        self.category = category
        self.icon = icon
        self.website = website
        self.safariCompatible = safariCompatible
        self.permissions = permissions
        self.canInjectScripts = canInjectScripts
        self.canModifyRequests = canModifyRequests
        self.canModifyHeaders = canModifyHeaders
        self.canAccessUserData = canAccessUserData
        self.canDisplayUIOverlay = canDisplayUIOverlay
        self.canIntegrateWithBrowserUI = canIntegrateWithBrowserUI
        self.activationState = activationState
    }
    
    // Handle events from the browser
    func handleEvent(_ event: ExtensionEvent) {
        switch event {
        case .pageLoad(let url):
            // By default, do nothing - subclasses should override
            break
        case .documentStart(let url):
            // Handle document start event
            break
        case .documentEnd(let url):
            // Handle document end event
            break
        case .pageUnload(let url):
            // Handle page unload
            break
        case .contentBlocked(let url, let request):
            // Content was blocked
            break
        case .formSubmission(let url, let formData):
            // Form was submitted
            break
        case .actionButtonClicked:
            // Toolbar button was clicked
            break
        case .contextMenuActivated(let url, let selectedText):
            // Context menu was activated
            break
        }
    }
}

// Extension for converting ExtensionIconType to SwiftUI Image
extension ExtensionIconType {
    func toImage() -> Image {
        switch self {
        case .system(let name):
            return Image(systemName: name)
        case .image(let name):
            return Image(name)
        case .data(let data):
            if let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            } else {
                return Image(systemName: "puzzlepiece.extension")
            }
        }
    }
} 