//
//  PillowApp.swift
//  Pillow
//
//  Created by Francesco Palladio on 06/05/25.
//

import SwiftUI
import UIKit
import WebKit
import Combine

@main
struct PillowApp: App {
    @StateObject private var browserViewModel = BrowserViewModel()
    
    init() {
        // Register default settings
        UserDefaults.registerDefaults()
    }
    
    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(browserViewModel)
        }
    }
}

class BrowserViewModel: ObservableObject {
    // Tabs
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabIndex: Int = 0
    @Published var isPrivateBrowsingEnabled: Bool = false
    
    // User interface
    @Published var showTabPicker: Bool = false
    
    // Default Tab and Search Engine Settings
    @Published var defaultTabURL: String {
        didSet {
            UserDefaults.standard.set(defaultTabURL, forKey: "DefaultTabURL")
        }
    }
    
    @Published var searchEngine: SearchEngineType {
        didSet {
            UserDefaults.standard.set(searchEngine.rawValue, forKey: "SearchEngine")
        }
    }
    
    // Settings
    @Published var userAgentType: UserAgentType
    @Published var customUserAgent: String
    @Published var blockPopups: Bool {
        didSet {
            UserDefaults.standard.blockPopups = blockPopups
        }
    }
    @Published var javascriptEnabled: Bool {
        didSet {
            UserDefaults.standard.javascriptEnabled = javascriptEnabled
        }
    }
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    var activeTab: BrowserTab? {
        guard !tabs.isEmpty, activeTabIndex >= 0, activeTabIndex < tabs.count else {
            return nil
        }
        return tabs[activeTabIndex]
    }
    
    var activeURL: URL {
        get {
            return activeTab?.url ?? URL(string: "https://www.google.com")!
        }
    }
    
    var isLoading: Bool {
        get { return activeTab?.isLoading ?? false }
        set { activeTab?.isLoading = newValue }
    }
    
    var canGoBack: Bool {
        get { return activeTab?.canGoBack ?? false }
    }
    
    var canGoForward: Bool {
        get { return activeTab?.canGoForward ?? false }
    }
    
    var pageTitle: String {
        get { return activeTab?.title ?? "" }
        set { activeTab?.title = newValue }
    }
    
    init() {
        // Load settings from UserDefaults
        let defaults = UserDefaults.standard
        self.userAgentType = defaults.userAgentType
        self.customUserAgent = defaults.customUserAgent
        self.blockPopups = defaults.blockPopups
        self.javascriptEnabled = defaults.javascriptEnabled
        
        // Load default tab URL
        self.defaultTabURL = defaults.string(forKey: "DefaultTabURL") ?? "https://www.google.com"
        
        // Load search engine setting
        let searchEngineValue = defaults.integer(forKey: "SearchEngine")
        self.searchEngine = SearchEngineType(rawValue: searchEngineValue) ?? .google
        
        // Create initial tab
        let initialTab = BrowserTab(url: URL(string: self.defaultTabURL)!)
        tabs.append(initialTab)
        
        // Set up notification observer for new tab creation
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(handleCreateNewTabNotification(_:)), 
                                              name: NSNotification.Name("CreateNewTab"), 
                                              object: nil)
    }
    
    @objc private func handleCreateNewTabNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo, let url = userInfo["url"] as? URL {
            DispatchQueue.main.async {
                self.createNewTab(url: url, isPrivate: self.isPrivateBrowsingEnabled)
            }
        }
    }
    
    // MARK: - Tab Management
    
    func createNewTab(url: URL? = nil, isPrivate: Bool? = nil) {
        let tabURL = url ?? URL(string: defaultTabURL)!
        let isTabPrivate = isPrivate ?? isPrivateBrowsingEnabled
        
        // Create new tab
        let newTab = BrowserTab(url: tabURL, isPrivate: isTabPrivate)
        tabs.append(newTab)
        activeTabIndex = tabs.count - 1
        
        // Setup WebView with proper configuration
        newTab.setupWebView(with: getWebViewConfiguration(isPrivate: isTabPrivate))
        
        // Apply user agent
        if let userAgentString = getUserAgentString(), !userAgentString.isEmpty {
            newTab.webView?.customUserAgent = userAgentString
        }
        
        // If this is a private tab, make sure private browsing is enabled
        if isTabPrivate && !isPrivateBrowsingEnabled {
            isPrivateBrowsingEnabled = true
        }
    }
    
    func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        
        // Clean up the WebView
        if let webView = tabs[index].webView {
            // Clean up any resources
            webView.stopLoading()
            webView.configuration.userContentController.removeAllUserScripts()
        }
        
        // Remove the tab
        tabs.remove(at: index)
        
        // Adjust active tab index if necessary
        if tabs.isEmpty {
            // Create a new tab if all tabs were closed
            createNewTab()
        } else if activeTabIndex >= tabs.count {
            // If the active tab was removed and it was the last tab, select the new last tab
            activeTabIndex = tabs.count - 1
        }
        
        // Check if we need to disable private browsing
        if isPrivateBrowsingEnabled && !tabs.contains(where: { $0.isPrivate }) {
            isPrivateBrowsingEnabled = false
        }
    }
    
    func switchToTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        
        // Update active tab index
        activeTabIndex = index
        
        // Update private browsing state if needed
        let selectedTab = tabs[index]
        if selectedTab.isPrivate && !isPrivateBrowsingEnabled {
            isPrivateBrowsingEnabled = true
        } else if !selectedTab.isPrivate && isPrivateBrowsingEnabled {
            // Only disable private browsing if there are no more private tabs
            if !tabs.contains(where: { $0.isPrivate && $0.id != selectedTab.id }) {
                isPrivateBrowsingEnabled = false
            }
        }
    }
    
    func togglePrivateBrowsing() {
        isPrivateBrowsingEnabled.toggle()
        
        // If turning on private browsing and no private tabs exist, create one
        if isPrivateBrowsingEnabled && !tabs.contains(where: { $0.isPrivate }) {
            // Don't create a new tab here - let the calling code do it if needed
        } else if !isPrivateBrowsingEnabled {
            // If turning off private browsing, switch to a non-private tab if active tab is private
            if activeTab?.isPrivate ?? false {
                if let firstNonPrivateIndex = tabs.firstIndex(where: { !$0.isPrivate }) {
                    switchToTab(at: firstNonPrivateIndex)
                } else {
                    // If no non-private tabs, create one
                    createNewTab(isPrivate: false)
                }
            }
        }
    }
    
    // MARK: - Navigation
    
    func navigateTo(urlString: String) {
        if activeTab == nil {
            createNewTab()
        }
        
        // Check if this is a search query or a URL
        if isSearchQuery(urlString) {
            performSearch(query: urlString)
        } else {
            activeTab?.loadURLString(urlString)
        }
    }
    
    private func isSearchQuery(_ input: String) -> Bool {
        // If it contains a space, it's probably a search query
        if input.contains(" ") {
            return true
        }
        
        // If it looks like a URL (has scheme or common TLD), it's not a search query
        if input.contains("://") || 
           input.hasSuffix(".com") || 
           input.hasSuffix(".org") || 
           input.hasSuffix(".net") || 
           input.hasSuffix(".edu") || 
           input.hasSuffix(".io") || 
           input.hasSuffix(".dev") {
            return false
        }
        
        // If it has dots but no spaces, try to determine if it's a domain
        if input.contains(".") {
            return !input.contains("/")
        }
        
        // Otherwise, treat as search query
        return true
    }
    
    func performSearch(query: String) {
        if let activeTab = activeTab {
            let searchURL = searchEngine.searchURL(for: query)
            activeTab.loadURL(searchURL)
        }
    }
    
    func updateCurrentURLWithoutNavigating(url: URL) {
        if let activeTab = activeTab {
            activeTab.url = url
        }
    }
    
    func goBack() {
        activeTab?.goBack()
    }
    
    func goForward() {
        activeTab?.goForward()
    }
    
    func reload() {
        activeTab?.reload()
    }
    
    func stopLoading() {
        activeTab?.stopLoading()
    }
    
    // MARK: - WebView Configuration
    
    func getWebViewConfiguration(isPrivate: Bool = false) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        
        // Configure preferences
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = javascriptEnabled
        config.defaultWebpagePreferences = prefs
        
        // Configure website data store
        if isPrivate {
            // Use ephemeral storage for private browsing
            config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
            
            // Additional privacy settings for private browsing
            let preferences = WKPreferences()
            preferences.javaScriptCanOpenWindowsAutomatically = false // More restrictive for private mode
            config.preferences = preferences
            
            // Clear any existing website data to be extra safe
            WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                for record in records where record.displayName.contains("pillow-private") {
                    WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), 
                                                          for: [record], 
                                                          completionHandler: {})
                }
            }
            
            // Set up a content rule list to block trackers in private mode
            if let path = Bundle.main.path(forResource: "ContentBlockingRules", ofType: "json") {
                do {
                    let ruleList = try String(contentsOfFile: path)
                    WKContentRuleListStore.default().compileContentRuleList(
                        forIdentifier: "ContentBlockingRules",
                        encodedContentRuleList: ruleList) { contentRuleList, error in
                            if let error = error {
                                print("Error compiling content blocking rules: \(error)")
                                return
                            }
                            
                            if let contentRuleList = contentRuleList {
                                config.userContentController.add(contentRuleList)
                            }
                        }
                } catch {
                    print("Error loading content blocking rules: \(error)")
                }
            }
        } else {
            config.websiteDataStore = WKWebsiteDataStore.default()
        }
        
        // Configure popup blocking
        config.preferences.javaScriptCanOpenWindowsAutomatically = !blockPopups
        
        return config
    }
    
    // MARK: - Settings Functions
    
    func setUserAgent(type: UserAgentType) {
        userAgentType = type
        UserDefaults.standard.userAgentType = type
        applyUserAgentToAllTabs()
    }
    
    func setCustomUserAgent(_ userAgent: String) {
        customUserAgent = userAgent
        UserDefaults.standard.customUserAgent = userAgent
        userAgentType = .custom
        UserDefaults.standard.userAgentType = .custom
        applyUserAgentToAllTabs()
    }
    
    func getUserAgentString() -> String? {
        if userAgentType == .custom {
            return customUserAgent.isEmpty ? nil : customUserAgent
        } else {
            return userAgentType.userAgentString.isEmpty ? nil : userAgentType.userAgentString
        }
    }
    
    private func applyUserAgentToAllTabs() {
        guard let userAgentString = getUserAgentString(), !userAgentString.isEmpty else { return }
        
        for tab in tabs {
            tab.webView?.customUserAgent = userAgentString
        }
    }
    
    func clearCache() {
        // Create a set of data types to remove
        let dataTypes = Set([
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeWebSQLDatabases,
            WKWebsiteDataTypeIndexedDBDatabases
        ])
        
        // Get the date from a long time ago
        let date = Date(timeIntervalSince1970: 0)
        
        // Remove the data
        WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: date) {
            print("Browser cache cleared")
        }
    }
    
    func clearTabHistory() {
        for tab in tabs where !tab.isPrivate {
            tab.webView?.configuration.websiteDataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                tab.webView?.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {}
            }
        }
    }
    
    // MARK: - Default Tab Settings
    
    func setDefaultTabURL(_ url: String) {
        guard let _ = URL(string: url) else { return }
        defaultTabURL = url
    }
    
    // MARK: - Search Engine Settings
    
    func setSearchEngine(_ engine: SearchEngineType) {
        searchEngine = engine
        // No need to save to UserDefaults as the @Published property observer does this
    }
    
}

// MARK: - Search Engine Type Definition

enum SearchEngineType: Int, CaseIterable, Identifiable {
    case google = 0
    case duckDuckGo = 1
    case bing = 2
    case yahoo = 3
    case ecosia = 4
    case startpage = 5
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        switch self {
        case .google:
            return "Google"
        case .duckDuckGo:
            return "DuckDuckGo"
        case .bing:
            return "Bing"
        case .yahoo:
            return "Yahoo"
        case .ecosia:
            return "Ecosia"
        case .startpage:
            return "Startpage"
        }
    }
    
    var description: String {
        switch self {
        case .google:
            return "The most widely used search engine."
        case .duckDuckGo:
            return "Privacy-focused search engine that doesn't track you."
        case .bing:
            return "Microsoft's search engine."
        case .yahoo:
            return "Yahoo search."
        case .ecosia:
            return "The search engine that plants trees."
        case .startpage:
            return "Privacy-focused search engine."
        }
    }
    
    var baseURL: URL {
        switch self {
        case .google:
            return URL(string: "https://www.google.com")!
        case .duckDuckGo:
            return URL(string: "https://duckduckgo.com")!
        case .bing:
            return URL(string: "https://www.bing.com")!
        case .yahoo:
            return URL(string: "https://search.yahoo.com")!
        case .ecosia:
            return URL(string: "https://www.ecosia.org")!
        case .startpage:
            return URL(string: "https://www.startpage.com")!
        }
    }
    
    func searchURL(for query: String) -> URL {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        switch self {
        case .google:
            return URL(string: "https://www.google.com/search?q=\(encodedQuery)")!
        case .duckDuckGo:
            return URL(string: "https://duckduckgo.com/?q=\(encodedQuery)")!
        case .bing:
            return URL(string: "https://www.bing.com/search?q=\(encodedQuery)")!
        case .yahoo:
            return URL(string: "https://search.yahoo.com/search?p=\(encodedQuery)")!
        case .ecosia:
            return URL(string: "https://www.ecosia.org/search?q=\(encodedQuery)")!
        case .startpage:
            return URL(string: "https://www.startpage.com/do/search?q=\(encodedQuery)")!
        }
    }
}
