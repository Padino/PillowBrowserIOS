import Foundation
import WebKit
import Combine

class ExtensionManager: ObservableObject {
    // Available and installed extensions
    @Published var availableExtensions: [BrowserExtension] = []
    @Published var installedExtensions: [BrowserExtension] = []
    
    // Store extension scripts to avoid recalculation
    private var extensionScriptsCache: [String: [ExtensionScript]] = [:]
    
    // Track installed extensions by ID for quick access
    private var extensionsById: [String: BrowserExtension] = [:]
    
    // Internal state
    private var cancellables = Set<AnyCancellable>()
    private var isInitialized = false
    
    // Singleton instance
    static let shared = ExtensionManager()
    
    private init() {}
    
    // MARK: - Extension Management
    
    func initialize() {
        if isInitialized { return }
        
        // Load built-in extensions
        loadBuiltInExtensions()
        
        // Load user-installed extensions
        loadUserExtensions()
        
        // Index extensions by ID
        updateExtensionsIndex()
        
        // Mark as initialized
        isInitialized = true
    }
    
    private func loadBuiltInExtensions() {
        // Add built-in extensions
        let adBlocker = AdBlockerExtension()
        let darkMode = DarkModeExtension()
        let userAgent = UserAgentSpoofingExtension()
        
        availableExtensions.append(contentsOf: [adBlocker, darkMode, userAgent])
        
        // By default, install the ad blocker
        installExtension(adBlocker)
    }
    
    private func loadUserExtensions() {
        // This would load extensions from a directory or user settings
        // We'll just use some placeholders for now
        let userExtensionDefaults = UserDefaults.standard.array(forKey: "InstalledExtensions") as? [String] ?? []
        
        // For demonstration purposes, we're not actually loading from files
        if userExtensionDefaults.contains("password-manager") {
            let passwordManager = createPasswordManagerExtension()
            availableExtensions.append(passwordManager)
            installExtension(passwordManager)
        }
    }
    
    func installExtension(_ extension: BrowserExtension) {
        // Don't install duplicates
        if installedExtensions.contains(where: { $0.id == `extension`.id }) {
            return
        }
        
        // Initialize the extension
        `extension`.initialize()
        
        // Add to installed list
        installedExtensions.append(`extension`)
        
        // Update index
        extensionsById[`extension`.id] = `extension`
        
        // Save to user defaults
        saveInstalledExtensionsToUserDefaults()
    }
    
    func uninstallExtension(withID id: String) {
        if let index = installedExtensions.firstIndex(where: { $0.id == id }) {
            let extensionToRemove = installedExtensions[index]
            
            // Call cleanup
            extensionToRemove.cleanup()
            
            // Remove from list
            installedExtensions.remove(at: index)
            
            // Remove from index
            extensionsById.removeValue(forKey: id)
            
            // Save to user defaults
            saveInstalledExtensionsToUserDefaults()
        }
    }
    
    func toggleExtension(withID id: String) {
        if let extensionIndex = installedExtensions.firstIndex(where: { $0.id == id }) {
            installedExtensions[extensionIndex].isEnabled.toggle()
            
            // Update in index
            extensionsById[id]?.isEnabled = installedExtensions[extensionIndex].isEnabled
            
            // Clear cache for this extension
            extensionScriptsCache = [:]
            
            saveInstalledExtensionsToUserDefaults()
        }
    }
    
    private func saveInstalledExtensionsToUserDefaults() {
        let installedIDs = installedExtensions.map { $0.id }
        UserDefaults.standard.set(installedIDs, forKey: "InstalledExtensions")
    }
    
    private func updateExtensionsIndex() {
        extensionsById.removeAll()
        for ext in installedExtensions {
            extensionsById[ext.id] = ext
        }
    }
    
    // MARK: - Extension Functionality
    
    func applyExtensionsToWebView(_ webView: WKWebView) {
        // Set up content controller
        let contentController = webView.configuration.userContentController
        
        // Only if we have extensions that can inject scripts
        let scriptInjectors = enabledExtensions.filter { $0.canInjectScripts }
        
        if !scriptInjectors.isEmpty {
            // Remove existing message handler if it exists to avoid duplicates
            contentController.removeScriptMessageHandler(forName: "extensionMessageHandler")
            
            // Add script message handlers for extension communication
            contentController.add(ScriptMessageHandler(manager: self), name: "extensionMessageHandler")
            
            // Clear existing scripts to avoid duplicates
            contentController.removeAllUserScripts()
            
            // Add extension scripts
            let url = webView.url ?? URL(string: "about:blank")!
            let host = url.host ?? ""
            
            // First add scripts that run at document start
            addScriptsToWebView(webView, forURL: url, atTime: .atStart)
            
            // Then add scripts that run at document end
            addScriptsToWebView(webView, forURL: url, atTime: .atEnd)
            
            // Add scripts for DOM content loaded
            addScriptsToWebView(webView, forURL: url, atTime: .onDOMContentLoaded)
            
            // Add scripts for page load complete
            addScriptsToWebView(webView, forURL: url, atTime: .onPageLoad)
            
            // Notify extensions about the impending page load
            notifyExtensions(event: .documentStart(url))
        }
    }
    
    private func addScriptsToWebView(_ webView: WKWebView, forURL url: URL, atTime injectionTime: ExtensionScriptInjectionTime) {
        let host = url.host ?? ""
        let wkInjectionTime = convertInjectionTime(injectionTime)
        
        for ext in enabledExtensions.filter({ $0.canInjectScripts }) {
            // Skip if not active for this domain
            if !ext.isActiveForDomain(host) { continue }
            
            // Get scripts from extension
            if let scripts = ext.getScriptsToInject(for: url)?.filter({ $0.injectionTime == injectionTime }) {
                for script in scripts {
                    // Check if script is for all URLs or this specific URL
                    if script.forURL == nil || script.forURL?.host == url.host {
                        // Create a wrapper script that provides communication APIs
                        let wrappedScript = wrapScriptWithCommunicationAPI(
                            script.content,
                            extensionId: ext.id
                        )
                        
                        let wkScript = WKUserScript(
                            source: wrappedScript,
                            injectionTime: wkInjectionTime,
                            forMainFrameOnly: true
                        )
                        webView.configuration.userContentController.addUserScript(wkScript)
                    }
                }
            }
        }
    }
    
    private func wrapScriptWithCommunicationAPI(_ script: String, extensionId: String) -> String {
        // Add a wrapper to provide extension communication APIs
        return """
        (function() {
            // Extension Communication API
            window.pillow = window.pillow || {};
            window.pillow.extension = {
                id: "\(extensionId)",
                
                // Send message to native code
                sendMessage: function(message) {
                    try {
                        window.webkit.messageHandlers.extensionMessageHandler.postMessage({
                            extensionId: "\(extensionId)",
                            message: message
                        });
                    } catch(e) {
                        console.error('Failed to send extension message:', e);
                    }
                },
                
                // Storage API (simplified)
                storage: {
                    get: function(key) {
                        const storageData = localStorage.getItem('pillow_extension_\(extensionId)') || '{}';
                        const data = JSON.parse(storageData);
                        return data[key];
                    },
                    set: function(key, value) {
                        const storageData = localStorage.getItem('pillow_extension_\(extensionId)') || '{}';
                        const data = JSON.parse(storageData);
                        data[key] = value;
                        localStorage.setItem('pillow_extension_\(extensionId)', JSON.stringify(data));
                        this.sendMessage({type: 'storage_updated', key: key});
                        return true;
                    }
                }
            };
            
            // The actual extension script
            \(script)
        })();
        """
    }
    
    // Script message handler for extension communication
    class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
        weak var manager: ExtensionManager?
        
        init(manager: ExtensionManager) {
            self.manager = manager
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let manager = manager,
                  let body = message.body as? [String: Any],
                  let extensionId = body["extensionId"] as? String,
                  let extensionMessage = body["message"] else {
                return
            }
            
            // Process message from extension
            manager.handleExtensionMessage(extensionId: extensionId, message: extensionMessage)
        }
    }
    
    private func handleExtensionMessage(extensionId: String, message: Any) {
        // Find the extension that sent the message
        guard let ext = extensionsById[extensionId] else { return }
        
        // Handle message based on its type
        if let messageDict = message as? [String: Any],
           let messageType = messageDict["type"] as? String {
            
            switch messageType {
            case "storage_updated":
                // Extension updated its storage
                // Could sync with native storage if needed
                break
                
            case "content_blocked":
                if let url = messageDict["url"] as? String,
                   let urlObj = URL(string: url) {
                    // Extension blocked some content
                    // Could log or notify user if needed
                }
                break
                
            default:
                // Unknown message type
                print("Unknown extension message type: \(messageType)")
                break
            }
        }
    }
    
    func shouldBlockRequest(_ request: URLRequest) -> Bool {
        guard let url = request.url, let host = url.host else { return false }
        
        // Check if any enabled extension wants to block this request
        return enabledExtensions.filter { $0.canModifyRequests && $0.isActiveForDomain(host) }
            .contains { $0.shouldBlockRequest(request) }
    }
    
    func modifyRequest(_ request: URLRequest) -> URLRequest {
        guard let url = request.url, let host = url.host else { return request }
        
        // Apply request modifications from all enabled extensions
        var modifiedRequest = request
        
        for ext in enabledExtensions.filter({ $0.canModifyRequests && $0.isActiveForDomain(host) }) {
            modifiedRequest = ext.modifyRequest(modifiedRequest)
        }
        
        return modifiedRequest
    }
    
    func notifyExtensionsPageLoaded(webView: WKWebView, url: URL) {
        notifyExtensions(event: .pageLoad(url))
    }
    
    func notifyExtensionsPageUnloaded(url: URL) {
        notifyExtensions(event: .pageUnload(url))
    }
    
    func notifyExtensionsFormSubmitted(url: URL, formData: [String: String]) {
        notifyExtensions(event: .formSubmission(url, formData))
    }
    
    func notifyExtensionsContextMenu(url: URL, selectedText: String?) {
        notifyExtensions(event: .contextMenuActivated(url, selectedText))
    }
    
    private func notifyExtensions(event: ExtensionEvent) {
        // Check if the event has a URL to filter by domain
        var host: String? = nil
        
        switch event {
        case .pageLoad(let url), 
             .pageUnload(let url), 
             .documentStart(let url), 
             .documentEnd(let url),
             .contentBlocked(let url, _),
             .formSubmission(let url, _),
             .contextMenuActivated(let url, _):
            host = url.host
        default:
            // Events without URLs affect all extensions
            break
        }
        
        // Notify applicable extensions
        if let host = host {
            for ext in enabledExtensions.filter({ $0.isActiveForDomain(host) }) {
                ext.handleEvent(event)
            }
        } else {
            // If no host to filter by, notify all enabled extensions
            for ext in enabledExtensions {
                ext.handleEvent(event)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    var enabledExtensions: [BrowserExtension] {
        return installedExtensions.filter { $0.isEnabled }
    }
    
    private func convertInjectionTime(_ time: ExtensionScriptInjectionTime) -> WKUserScriptInjectionTime {
        switch time {
        case .atStart, .atEnd:
            return .atDocumentStart
        case .onDOMContentLoaded, .onPageLoad:
            return .atDocumentEnd
        }
    }
    
    // MARK: - Sample Extension Creation (for demo purposes)
    
    private func createPasswordManagerExtension() -> BrowserExtension {
        return BaseBrowserExtension(
            id: "password-manager",
            name: "Password Manager",
            version: "1.0",
            description: "Manages and autofills passwords",
            author: "Pillow Browser",
            icon: .system(name: "key.fill"),
            isEnabled: true,
            canInjectScripts: true,
            canModifyRequests: false,
            canModifyHeaders: false,
            canAccessUserData: true,
            activationState: .always
        )
    }
    
    // MARK: - Extension Toolbar and Context Menu
    
    func getToolbarItemsForWebView(_ webView: WKWebView?) -> [ExtensionToolbarItem] {
        guard let webView = webView, let url = webView.url, let host = url.host else {
            return []
        }
        
        var items: [ExtensionToolbarItem] = []
        
        // Get toolbar items from all enabled extensions that are active for this domain
        for ext in enabledExtensions.filter({ $0.isActiveForDomain(host) && $0.canIntegrateWithBrowserUI }) {
            if let toolbarItem = ext.toolbarItem {
                items.append(toolbarItem)
            }
        }
        
        return items
    }
    
    func getContextMenuItemsForWebView(_ webView: WKWebView?, selectedText: String?) -> [ExtensionContextMenuItem] {
        guard let webView = webView, let url = webView.url, let host = url.host else {
            return []
        }
        
        var items: [ExtensionContextMenuItem] = []
        
        // Get context menu items from all enabled extensions that are active for this domain
        for ext in enabledExtensions.filter({ $0.isActiveForDomain(host) && $0.canIntegrateWithBrowserUI }) {
            for item in ext.contextMenuItems {
                // If the item requires selection, ensure there is selected text
                if item.requiresSelection {
                    if let selectedText = selectedText, !selectedText.isEmpty {
                        items.append(item)
                    }
                } else {
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    func handleToolbarItemTapped(extensionID: String, toolbarItemID: String, webView: WKWebView?) {
        // Find the extension
        if let ext = extensionsById[extensionID] {
            // Notify the extension
            ext.onToolbarItemTapped(webView: webView)
            
            // Also send an event
            ext.handleEvent(.actionButtonClicked)
        }
    }
    
    func handleContextMenuItemSelected(extensionID: String, itemID: String, webView: WKWebView?) {
        // Find the extension
        if let ext = extensionsById[extensionID] {
            // Notify the extension
            ext.onContextMenuItemSelected(item: itemID, webView: webView)
        }
    }
} 