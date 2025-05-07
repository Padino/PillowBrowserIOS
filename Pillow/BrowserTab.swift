import Foundation
import WebKit

class BrowserTab: Identifiable, ObservableObject {
    let id = UUID()
    let isPrivate: Bool
    
    @Published var url: URL
    @Published var title: String = ""
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var webView: WKWebView?
    
    init(url: URL, isPrivate: Bool = false) {
        self.url = url
        self.isPrivate = isPrivate
    }
    
    func setupWebView(with configuration: WKWebViewConfiguration) {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView = webView
        
        // Now load the URL
        loadURL(url)
    }
    
    func loadURL(_ url: URL) {
        self.url = url
        
        // Create a request
        let request = URLRequest(url: url)
        
        // Load the request
        webView?.load(request)
    }
    
    func loadURLString(_ urlString: String) {
        var processedURL = urlString
        
        // Check if the URL has a scheme, if not add https://
        if !urlString.contains("://") {
            processedURL = "https://" + urlString
        }
        
        guard let url = URL(string: processedURL) else {
            print("Invalid URL: \(processedURL)")
            return
        }
        
        loadURL(url)
    }
    
    func goBack() {
        webView?.goBack()
    }
    
    func goForward() {
        webView?.goForward()
    }
    
    func reload() {
        webView?.reload()
    }
    
    func stopLoading() {
        webView?.stopLoading()
        isLoading = false
    }
} 