import Foundation
import WebKit

// MARK: - Ad Blocker Extension

class AdBlockerExtension: BaseBrowserExtension {
    // Comprehensive list of ad domains to block
    private let adDomains = [
        // Ad networks
        "doubleclick.net",
        "googleadservices.com",
        "googlesyndication.com",
        "adservice.google.com",
        "g.doubleclick.net",
        "pagead2.googlesyndication.com",
        "adnxs.com",
        "moatads.com",
        "rubiconproject.com",
        "criteo.com",
        "taboola.com",
        "outbrain.com",
        "adform.net",
        "pubmatic.com",
        "openx.net",
        "smartadserver.com",
        
        // Analytics and tracking
        "google-analytics.com",
        "googletagmanager.com",
        "googletagservices.com",
        "analytics.yahoo.com",
        "scorecardresearch.com",
        "quantserve.com",
        "hotjar.com",
        "amazon-adsystem.com",
        "facebook.com/tr",
        "facebook.net/tr",
        "pixel.facebook.com",
        "pixel.twitter.com",
        "ads.linkedin.com"
    ]
    
    // Common ad selector patterns
    private let adSelectors = [
        // Common id patterns
        "[id*='ad-']",
        "[id*='ad_']",
        "[id*='_ad_']",
        "[id*='_ads_']",
        "[id*='googlead']",
        "[id*='adsense']",
        "[id*='advert']",
        "[id*='banner']",
        "[id*='sponsor']",
        
        // Common class patterns
        "[class*='ad-']",
        "[class*='ad_']",
        "[class*='_ad_']",
        "[class*='_ads_']",
        "[class*='adblock']",
        "[class*='adbanner']",
        "[class*='googlead']",
        "[class*='adsense']",
        "[class*='advert']",
        "[class*='sponsored']",
        
        // Common ad containers
        "div[class*='banner']",
        "div[id*='banner']",
        "aside[class*='ad']",
        "aside[id*='ad']",
        
        // Specific ad elements
        "iframe[src*='doubleclick']",
        "iframe[src*='googlead']",
        "iframe[src*='ad-']",
        "iframe[src*='adserv']",
        "img[src*='ad.']",
        "a[href*='adclick']"
    ]
    
    private var blockedCount: Int = 0
    
    // Custom storage for user preferences
    private var customBlockRules: [String] = []
    private var whitelistedDomains: [String] = []
    
    init() {
        super.init(
            id: "ad-blocker",
            name: "Ad Blocker",
            version: "1.0",
            description: "Blocks advertisements and trackers for faster, cleaner browsing",
            author: "Pillow Browser",
            icon: .system(name: "shield.fill"),
            isEnabled: true,
            category: .contentBlocker,
            permissions: [.blockContent, .modifyWebContent],
            canInjectScripts: true,
            canModifyRequests: true,
            canModifyHeaders: false,
            canAccessUserData: false,
            canIntegrateWithBrowserUI: true,
            activationState: .blocklist([])
        )
        
        // Load custom settings
        loadSettings()
    }
    
    var toolbarItem: ExtensionToolbarItem? {
        return ExtensionToolbarItem(
            id: "toggle-adblock",
            title: "Toggle Ad Blocker",
            icon: .system(name: "shield.fill"),
            badge: "ON"
        )
    }
    
    private func loadSettings() {
        // In a real implementation, this would load from UserDefaults or a database
        // For now, we'll use hardcoded values
        customBlockRules = []
        whitelistedDomains = []
    }
    
    // Add a custom domain to block
    func addCustomBlockRule(_ rule: String) {
        customBlockRules.append(rule)
    }
    
    // Add a domain to whitelist (don't block ads)
    func addWhitelistedDomain(_ domain: String) {
        whitelistedDomains.append(domain)
        
        // Update activation state
        activationState = .blocklist(whitelistedDomains)
    }
    
    func isActiveForDomain(_ domain: String) -> Bool {
        // Don't block ads on whitelisted domains
        if whitelistedDomains.contains(where: { domain.hasSuffix($0) }) {
            return false
        }
        return isEnabled
    }
    
    func shouldBlockRequest(_ request: URLRequest) -> Bool {
        guard isEnabled, let url = request.url, let host = url.host else { return false }
        
        // Don't block on whitelisted domains
        if let domain = getDomain(from: url), 
           whitelistedDomains.contains(where: { domain.hasSuffix($0) }) {
            return false
        }
        
        // Check if the host matches any ad domain
        let shouldBlock = adDomains.contains { adDomain in
            return host == adDomain || host.hasSuffix(".\(adDomain)")
        }
        
        if shouldBlock {
            blockedCount += 1
        }
        
        return shouldBlock
    }
    
    private func getDomain(from url: URL) -> String? {
        guard let host = url.host else { return nil }
        
        // Extract base domain from host
        let components = host.components(separatedBy: ".")
        if components.count > 2 {
            // For subdomains like "ads.example.com", return "example.com"
            return components.suffix(2).joined(separator: ".")
        }
        return host
    }
    
    func getScriptsToInject(for url: URL) -> [ExtensionScript]? {
        // Don't inject on whitelisted domains
        if let domain = getDomain(from: url), 
           whitelistedDomains.contains(where: { domain.hasSuffix($0) }) {
            return nil
        }
        
        // Create a comprehensive ad blocker script
        let adBlockScript = """
        (function() {
            // Counter for blocked elements
            let blockedElementCount = 0;
            
            // Standard CSS selectors for ads
            const adSelectors = \(adSelectors);
            
            // Function to hide ad elements
            function hideAds() {
                for (const selector of adSelectors) {
                    try {
                        document.querySelectorAll(selector).forEach(el => {
                            if (el.style.display !== 'none') {
                                el.style.display = 'none';
                                blockedElementCount++;
                                
                                // Report blocked elements to extension
                                if (window.pillow && window.pillow.extension) {
                                    window.pillow.extension.sendMessage({
                                        type: 'content_blocked',
                                        url: window.location.href,
                                        selector: selector
                                    });
                                }
                            }
                        });
                    } catch (e) {
                        // Ignore errors from selector queries
                    }
                }
            }
            
            // Run immediately 
            hideAds();
            
            // Also after page has loaded
            window.addEventListener('load', hideAds);
            
            // And on DOM mutations (for dynamically added ads)
            const observer = new MutationObserver(function(mutations) {
                hideAds();
                
                // Also check for iframes trying to load ads
                for (const mutation of mutations) {
                    for (const node of mutation.addedNodes) {
                        if (node.tagName === 'IFRAME') {
                            const src = node.src || '';
                            if (src.includes('ad') || 
                                src.includes('banner') || 
                                src.includes('sponsor') || 
                                src.includes('doubleclick') || 
                                src.includes('googlesynd')) {
                                node.style.display = 'none';
                                blockedElementCount++;
                            }
                        }
                    }
                }
            });
            
            // Start observing when DOM is ready
            if (document.body) {
                observer.observe(document.body, { 
                    childList: true, 
                    subtree: true 
                });
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    observer.observe(document.body, { 
                        childList: true, 
                        subtree: true 
                    });
                });
            }
            
            // Store stats in extension storage
            if (window.pillow && window.pillow.extension && window.pillow.extension.storage) {
                setInterval(function() {
                    if (blockedElementCount > 0) {
                        window.pillow.extension.storage.set('blockedCount', blockedElementCount);
                    }
                }, 2000);
            }
        })();
        """
        
        return [
            ExtensionScript(content: adBlockScript, injectionTime: .atStart)
        ]
    }
    
    func onToolbarItemTapped(webView: WKWebView?) {
        // Toggle enabled state for current domain
        if let webView = webView, let url = webView.url, let domain = getDomain(from: url) {
            if whitelistedDomains.contains(where: { domain.hasSuffix($0) }) {
                // Remove from whitelist
                whitelistedDomains.removeAll { domain.hasSuffix($0) }
            } else {
                // Add to whitelist
                whitelistedDomains.append(domain)
            }
            
            // Update activation state
            activationState = .blocklist(whitelistedDomains)
            
            // Reload the page to apply changes
            webView.reload()
        }
    }
    
    override func handleEvent(_ event: ExtensionEvent) {
        switch event {
        case .contentBlocked(let url, _):
            // Could track statistics here
            blockedCount += 1
        default:
            break
        }
    }
}

// MARK: - Dark Mode Extension

class DarkModeExtension: BaseBrowserExtension {
    // Sites that already have good dark mode support
    private let sitesWithNativeDarkMode = [
        "youtube.com",
        "netflix.com",
        "disneyplus.com",
        "hulu.com",
        "twitter.com",
        "reddit.com",
        "github.com"
    ]
    
    // Custom preferences
    private var excludedDomains: [String] = []
    private var colorScheme: DarkModeColorScheme = .dark
    private var contrastLevel: Float = 1.0
    private var preserveImages: Bool = true
    
    init() {
        super.init(
            id: "dark-mode",
            name: "Dark Mode",
            version: "1.0",
            description: "Applies customizable dark mode to websites",
            author: "Pillow Browser",
            icon: .system(name: "moon.fill"),
            isEnabled: false,
            category: .appearance,
            permissions: [.modifyWebContent],
            canInjectScripts: true,
            canModifyRequests: false,
            canModifyHeaders: false,
            canAccessUserData: false,
            canIntegrateWithBrowserUI: true,
            activationState: .blocklist([])
        )
        
        // Load user preferences
        loadSettings()
        
        // Initialize exclusion list with sites that have native dark mode
        activationState = .blocklist(sitesWithNativeDarkMode + excludedDomains)
    }
    
    var toolbarItem: ExtensionToolbarItem? {
        return ExtensionToolbarItem(
            id: "toggle-dark-mode",
            title: "Toggle Dark Mode",
            icon: .system(name: "moon.fill")
        )
    }
    
    private func loadSettings() {
        // In a real implementation, this would load from UserDefaults or a database
        excludedDomains = []
        colorScheme = .dark
        contrastLevel = 1.0
        preserveImages = true
    }
    
    // Add a domain to excluded list
    func addExcludedDomain(_ domain: String) {
        excludedDomains.append(domain)
        
        // Update activation state
        let blocklist = sitesWithNativeDarkMode + excludedDomains
        activationState = .blocklist(blocklist)
    }
    
    // Remove a domain from excluded list
    func removeExcludedDomain(_ domain: String) {
        excludedDomains.removeAll { $0 == domain }
        
        // Update activation state
        let blocklist = sitesWithNativeDarkMode + excludedDomains
        activationState = .blocklist(blocklist)
    }
    
    // Set the color scheme
    func setColorScheme(_ scheme: DarkModeColorScheme) {
        colorScheme = scheme
    }
    
    // Set contrast level
    func setContrastLevel(_ level: Float) {
        contrastLevel = level
    }
    
    // Toggle image preservation
    func setPreserveImages(_ preserve: Bool) {
        preserveImages = preserve
    }
    
    func getScriptsToInject(for url: URL) -> [ExtensionScript]? {
        // Get the domain
        guard let domain = getDomain(from: url) else { return nil }
        
        // Skip if domain is in the blocklist
        if sitesWithNativeDarkMode.contains(where: { domain.hasSuffix($0) }) || 
           excludedDomains.contains(where: { domain.hasSuffix($0) }) {
            return nil
        }
        
        // Generate dark mode script with current settings
        let darkModeScript = """
        (function() {
            // Prevent multiple initializations
            if (window.pillowDarkModeApplied) return;
            window.pillowDarkModeApplied = true;
            
            // Configuration from extension settings
            const config = {
                colorScheme: "\(colorScheme.rawValue)",
                contrastLevel: \(contrastLevel),
                preserveImages: \(preserveImages)
            };
            
            // Don't apply dark mode if the website already has dark mode
            function isAlreadyDarkMode() {
                // Get the computed background color of the body
                const bodyBg = window.getComputedStyle(document.body).backgroundColor;
                const htmlBg = window.getComputedStyle(document.documentElement).backgroundColor;
                
                // Convert RGB to brightness (simple formula: (R+G+B)/3)
                function getBrightness(color) {
                    // Handle rgba and rgb format
                    const rgb = color.match(/\\d+/g);
                    if (!rgb || rgb.length < 3) return 255; // Default to bright if can't parse
                    
                    const r = parseInt(rgb[0]);
                    const g = parseInt(rgb[1]);
                    const b = parseInt(rgb[2]);
                    return (r + g + b) / 3;
                }
                
                // Check if the background is already dark (brightness < 128)
                const bodyBrightness = getBrightness(bodyBg);
                const htmlBrightness = getBrightness(htmlBg);
                
                // Also check for dark mode preference in CSS
                const prefersDarkMode = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
                const hasDataThemeDark = document.documentElement.getAttribute('data-theme') === 'dark';
                
                return (bodyBrightness < 128 || htmlBrightness < 128 || prefersDarkMode || hasDataThemeDark);
            }
            
            // Check if site has a dark mode toggle or setting we can activate
            function tryNativeDarkMode() {
                // Try common dark mode toggles and settings
                const darkModeSelectors = [
                    '#dark-mode-toggle',
                    '.dark-mode-toggle',
                    '#darkModeToggle',
                    '.darkModeToggle',
                    '[data-testid="dark-mode-toggle"]',
                    '[aria-label="Toggle dark mode"]',
                    '[aria-label="Dark mode"]',
                    '#night-mode',
                    '.night-mode-toggle',
                    '.color-scheme-toggle'
                ];
                
                for (const selector of darkModeSelectors) {
                    const toggle = document.querySelector(selector);
                    if (toggle) {
                        toggle.click();
                        return true;
                    }
                }
                
                // Common dark mode class toggles
                try {
                    document.documentElement.classList.add('dark-mode');
                    document.documentElement.classList.add('dark');
                    document.documentElement.classList.add('theme-dark');
                    document.documentElement.classList.add('darkmode');
                    
                    // Common dark mode attributes
                    document.documentElement.setAttribute('data-theme', 'dark');
                    document.documentElement.setAttribute('data-color-scheme', 'dark');
                    document.documentElement.setAttribute('data-bs-theme', 'dark');
                    
                    // localStorage settings
                    try {
                        localStorage.setItem('theme', 'dark');
                        localStorage.setItem('darkMode', 'true');
                        localStorage.setItem('isDarkMode', 'true');
                        localStorage.setItem('color-scheme', 'dark');
                    } catch (e) {}
                    
                    return true;
                } catch (e) {
                    return false;
                }
            }
            
            // Get color scheme based on settings
            function getColors() {
                switch (config.colorScheme) {
                    case 'dark':
                        return {
                            background: '#1a1a1a',
                            text: '#e8e8e8',
                            link: '#6da8ff',
                            border: '#444'
                        };
                    case 'blue':
                        return {
                            background: '#172a3a',
                            text: '#e8e8e8',
                            link: '#6da8ff',
                            border: '#2c5a7c'
                        };
                    case 'sepia':
                        return {
                            background: '#251e12',
                            text: '#e8d8b7',
                            link: '#be8f65',
                            border: '#4e3e29'
                        };
                    case 'green':
                        return {
                            background: '#1a2a1e',
                            text: '#d8e8df',
                            link: '#8fc786',
                            border: '#345239'
                        };
                    case 'grey':
                        return {
                            background: '#2a2a2a',
                            text: '#d0d0d0',
                            link: '#a0a0a0',
                            border: '#5a5a5a'
                        };
                    default:
                        return {
                            background: '#1a1a1a',
                            text: '#e8e8e8',
                            link: '#6da8ff',
                            border: '#444'
                        };
                }
            }
            
            // Apply custom dark mode
            function applyDarkMode() {
                // Create a style element for our dark mode
                const style = document.createElement('style');
                style.setAttribute('id', 'pillow-dark-mode');
                
                // Get color scheme
                const colors = getColors();
                
                // Create CSS based on configuration
                style.textContent = `
                    html, body {
                        background-color: ${colors.background} !important;
                        color: ${colors.text} !important;
                    }
                    
                    /* Basic text and background adjustments */
                    div, p, span, h1, h2, h3, h4, h5, h6, article, section, header, footer, nav, main, aside {
                        background-color: ${colors.background} !important;
                        color: ${colors.text} !important;
                        border-color: ${colors.border} !important;
                    }
                    
                    /* Links */
                    a, a:link, a:visited {
                        color: ${colors.link} !important;
                    }
                    
                    a:hover, a:active {
                        color: ${colors.link} !important;
                        filter: brightness(1.2);
                    }
                    
                    /* Inputs and forms */
                    input, textarea, select, button {
                        background-color: ${colors.background} !important;
                        filter: brightness(1.2);
                        color: ${colors.text} !important;
                        border-color: ${colors.border} !important;
                    }
                    
                    button, .button, [class*='btn'] {
                        background-color: ${colors.background} !important;
                        filter: brightness(1.3);
                        color: ${colors.text} !important;
                        border-color: ${colors.border} !important;
                    }
                    
                    /* Tables */
                    table, tr, td, th {
                        background-color: ${colors.background} !important;
                        color: ${colors.text} !important;
                        border-color: ${colors.border} !important;
                    }
                    
                    th {
                        background-color: ${colors.background} !important;
                        filter: brightness(1.2);
                    }
                    
                    /* Fix media - don't invert images and videos if preserveImages is true */
                    ${config.preserveImages ? `
                        img, video, picture, canvas, svg {
                            filter: brightness(${0.8 * config.contrastLevel}) contrast(${1.2 * config.contrastLevel});
                        }
                    ` : `
                        img, video, picture, canvas, svg {
                            filter: invert(1) hue-rotate(180deg);
                        }
                    `}
                    
                    /* Handle ::before and ::after pseudo-elements */
                    ::before, ::after {
                        background-color: inherit !important;
                        color: inherit !important;
                    }
                    
                    /* Some websites use a class or attribute to control dark mode */
                    [data-theme="dark"] {
                        filter: none !important;
                    }
                    
                    /* Preserve transparency */
                    [style*="background: transparent"],
                    [style*="background-color: transparent"],
                    [style*="background:transparent"],
                    [style*="background-color:transparent"] {
                        background-color: transparent !important;
                    }
                `;
                
                // Apply custom contrast level
                if (config.contrastLevel !== 1.0) {
                    style.textContent += `
                        html {
                            filter: contrast(${config.contrastLevel}) !important;
                        }
                    `;
                }
                
                // Add the style to document head
                document.head.appendChild(style);
                
                // Report to extension
                if (window.pillow && window.pillow.extension) {
                    window.pillow.extension.sendMessage({
                        type: 'dark_mode_applied',
                        url: window.location.href
                    });
                    
                    // Store status
                    window.pillow.extension.storage.set('darkModeEnabled', true);
                }
            }
            
            // Only apply dark mode if not already dark
            if (!isAlreadyDarkMode()) {
                // First try to activate the site's native dark mode
                const nativeDarkModeWorked = tryNativeDarkMode();
                
                // If that didn't work, apply our custom dark mode
                if (!nativeDarkModeWorked) {
                    // Wait for DOM to be ready
                    if (document.readyState === 'loading') {
                        document.addEventListener('DOMContentLoaded', applyDarkMode);
                    } else {
                        applyDarkMode();
                    }
                }
            } else {
                if (window.pillow && window.pillow.extension) {
                    window.pillow.extension.sendMessage({
                        type: 'native_dark_mode_detected',
                        url: window.location.href
                    });
                }
            }
            
            // Listen for extension commands
            if (window.pillow && window.pillow.extension) {
                // Custom event listener for extension communication
                document.addEventListener('pillow-extension-message', function(e) {
                    const message = e.detail;
                    if (message && message.type === 'toggle_dark_mode') {
                        const darkModeStyle = document.getElementById('pillow-dark-mode');
                        if (darkModeStyle) {
                            darkModeStyle.disabled = !darkModeStyle.disabled;
                            window.pillow.extension.storage.set('darkModeEnabled', !darkModeStyle.disabled);
                        } else {
                            applyDarkMode();
                        }
                    }
                });
            }
        })();
        """
        
        return [
            ExtensionScript(content: darkModeScript, injectionTime: .atStart)
        ]
    }
    
    private func getDomain(from url: URL) -> String? {
        guard let host = url.host else { return nil }
        
        // Extract base domain from host
        let components = host.components(separatedBy: ".")
        if components.count > 2 {
            // For subdomains like "www.example.com", return "example.com"
            return components.suffix(2).joined(separator: ".")
        }
        return host
    }
    
    func onToolbarItemTapped(webView: WKWebView?) {
        guard let webView = webView else { return }
        
        // Send a message to the page to toggle dark mode
        let script = """
        const event = new CustomEvent('pillow-extension-message', { 
            detail: { type: 'toggle_dark_mode' } 
        });
        document.dispatchEvent(event);
        """
        
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    override func handleEvent(_ event: ExtensionEvent) {
        switch event {
        case .pageLoad(let url):
            // Could track statistics here
            break
        default:
            break
        }
    }
    
    // Lifecycle method to handle cleanup
    func cleanup() {
        // This would ideally remove dark mode from all tabs
        // In a real implementation, we would send a message to a content script
        // to remove the dark mode styles
    }
}

// Dark mode color scheme options
enum DarkModeColorScheme: String {
    case dark = "dark"
    case blue = "blue"
    case sepia = "sepia"
    case green = "green"
    case grey = "grey"
}

// MARK: - User Agent Spoofing Extension

class UserAgentSpoofingExtension: BaseBrowserExtension {
    // Predefined user agent strings
    private let userAgents: [String: String] = [
        "Chrome Windows": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Chrome Mac": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Chrome Android": "Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36",
        "Firefox Windows": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0",
        "Firefox Mac": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:89.0) Gecko/20100101 Firefox/89.0",
        "Firefox Android": "Mozilla/5.0 (Android 12; Mobile; rv:68.0) Gecko/68.0 Firefox/89.0",
        "Safari Mac": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15",
        "Safari iOS": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
        "Edge Windows": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59",
        "Samsung Browser": "Mozilla/5.0 (Linux; Android 10; SAMSUNG SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/14.0 Chrome/87.0.4280.141 Mobile Safari/537.36",
        "Desktop": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mobile": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
        "Tablet": "Mozilla/5.0 (iPad; CPU OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
        "GoogleBot": "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        "BingBot": "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)"
    ]
    
    private var customUserAgent: String? = nil
    private var selectedPreset: String? = nil
    private var perSiteUserAgents: [String: String] = [:]
    
    // Context menu items
    private var contextMenuItemList: [ExtensionContextMenuItem] = [
        ExtensionContextMenuItem(
            id: "user-agent-desktop",
            title: "View as Desktop",
            icon: .system(name: "desktopcomputer"),
            requiresSelection: false
        ),
        ExtensionContextMenuItem(
            id: "user-agent-mobile",
            title: "View as Mobile",
            icon: .system(name: "iphone"),
            requiresSelection: false
        ),
        ExtensionContextMenuItem(
            id: "user-agent-reset",
            title: "Reset User Agent",
            icon: .system(name: "arrow.counterclockwise"),
            requiresSelection: false
        )
    ]
    
    init() {
        super.init(
            id: "user-agent-spoofer",
            name: "User Agent Spoofer",
            version: "1.0",
            description: "Spoof your user agent to view websites as if using different browsers or devices",
            author: "Pillow Browser",
            icon: .system(name: "person.fill.viewfinder"),
            isEnabled: false,
            category: .privacy,
            permissions: [.modifyWebContent, .modifyHeaders],
            canInjectScripts: false,
            canModifyRequests: true,
            canModifyHeaders: true,
            canAccessUserData: false,
            canIntegrateWithBrowserUI: true,
            activationState: .always
        )
        
        // Load saved settings
        loadSettings()
    }
    
    var toolbarItem: ExtensionToolbarItem? {
        return ExtensionToolbarItem(
            id: "user-agent-toggle",
            title: "Change User Agent",
            icon: .system(name: "person.fill.viewfinder")
        )
    }
    
    var contextMenuItems: [ExtensionContextMenuItem] {
        return contextMenuItemList
    }
    
    private func loadSettings() {
        // In a real implementation, this would load from UserDefaults or a database
        customUserAgent = nil
        selectedPreset = nil
        perSiteUserAgents = [:]
    }
    
    func setCustomUserAgent(_ userAgent: String) {
        customUserAgent = userAgent
        selectedPreset = nil
    }
    
    func setUserAgentPreset(_ preset: String) {
        if let userAgent = userAgents[preset] {
            customUserAgent = userAgent
            selectedPreset = preset
        }
    }
    
    func addSiteSpecificUserAgent(domain: String, userAgent: String) {
        perSiteUserAgents[domain] = userAgent
    }
    
    func removeSiteSpecificUserAgent(domain: String) {
        perSiteUserAgents.removeValue(forKey: domain)
    }
    
    func modifyRequest(_ request: URLRequest) -> URLRequest {
        guard isEnabled, let url = request.url, let host = url.host else {
            return request
        }
        
        var modifiedRequest = request
        
        // Determine which user agent to use
        let effectiveUserAgent = getUserAgentForDomain(host)
        
        if let effectiveUserAgent = effectiveUserAgent {
            // Add User-Agent header
            if let _ = modifiedRequest.allHTTPHeaderFields?["User-Agent"] {
                modifiedRequest.allHTTPHeaderFields?["User-Agent"] = effectiveUserAgent
            } else {
                // If there are no headers, create them
                var headers = modifiedRequest.allHTTPHeaderFields ?? [:]
                headers["User-Agent"] = effectiveUserAgent
                modifiedRequest.allHTTPHeaderFields = headers
            }
        }
        
        return modifiedRequest
    }
    
    private func getUserAgentForDomain(_ domain: String) -> String? {
        // Check if we have a domain-specific user agent
        for (siteDomain, userAgent) in perSiteUserAgents {
            if domain.hasSuffix(siteDomain) {
                return userAgent
            }
        }
        
        // Otherwise use the global user agent
        return customUserAgent
    }
    
    private func getDomain(from url: URL) -> String? {
        guard let host = url.host else { return nil }
        
        // Extract base domain from host
        let components = host.components(separatedBy: ".")
        if components.count > 2 {
            // For subdomains like "www.example.com", return "example.com"
            return components.suffix(2).joined(separator: ".")
        }
        return host
    }
    
    func onToolbarItemTapped(webView: WKWebView?) {
        // In a real implementation, this would show a popover with user agent options
        // For now, we'll just toggle between desktop and mobile user agents
        
        if customUserAgent == userAgents["Desktop"] {
            setUserAgentPreset("Mobile")
        } else {
            setUserAgentPreset("Desktop")
        }
        
        // Reload the page to apply the new user agent
        webView?.reload()
    }
    
    func onContextMenuItemSelected(item: String, webView: WKWebView?) {
        guard let webView = webView, let url = webView.url else { return }
        
        switch item {
        case "user-agent-desktop":
            setUserAgentPreset("Desktop")
        case "user-agent-mobile":
            setUserAgentPreset("Mobile")
        case "user-agent-reset":
            customUserAgent = nil
            selectedPreset = nil
        default:
            return
        }
        
        // Reload the page to apply the new user agent
        webView.reload()
    }
} 