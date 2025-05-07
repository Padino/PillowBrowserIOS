import SwiftUI
import UIKit
import WebKit
import Combine

struct BrowserView: View {
    @EnvironmentObject private var viewModel: BrowserViewModel
    @State private var urlText: String = "https://www.google.com"
    @State private var showSettings: Bool = false
    @State private var showTabs: Bool = false
    @State private var showBottomBar: Bool = true
    @State private var lastScrollY: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0
    
    // Constants for animations
    private let bottomBarHeight: CGFloat = 120
    private let animationDuration: Double = 0.3
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Progress bar
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                }
                
                // Private browsing indicator
                if viewModel.activeTab?.isPrivate ?? false {
                    HStack {
                        Image(systemName: "eyeglasses")
                        Text("Private Browsing")
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.05))
                }
                
                // Browser content
                if let activeTab = viewModel.activeTab {
                    ZStack {
                        // Create a ForEach for each tab, but only show the active one
                        ForEach(viewModel.tabs.indices, id: \.self) { index in
                            if index == viewModel.activeTabIndex {
                                TabWebView(tab: viewModel.tabs[index], onScroll: handleScroll)
                                    .edgesIgnoringSafeArea([.horizontal, .bottom])
                            }
                        }
                    }
                    .edgesIgnoringSafeArea([.horizontal, .bottom])
                } else {
                    // Fallback if no tab is active (shouldn't happen normally)
                    VStack {
                        Text("No active tab")
                        Button("Create New Tab") {
                            viewModel.createNewTab()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Bottom toolbar
            VStack(spacing: 0) {
                // URL Bar
                HStack(spacing: 8) {
                    // Tab count button
                    Button(action: {
                        showTabs = true
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.activeTab?.isPrivate ?? false ? Color.purple.opacity(0.2) : Color.gray.opacity(0.2))
                                .frame(width: 32, height: 22)
                            
                            Text("\(viewModel.tabs.count)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(viewModel.activeTab?.isPrivate ?? false ? .purple : .primary)
                        }
                    }
                    
                    // Private browsing toggle button
                    Button(action: {
                        viewModel.togglePrivateBrowsing()
                        if viewModel.isPrivateBrowsingEnabled && !viewModel.tabs.contains(where: { $0.isPrivate }) {
                            viewModel.createNewTab(isPrivate: true)
                        }
                    }) {
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 15))
                            .foregroundColor(viewModel.isPrivateBrowsingEnabled ? .white : .purple)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(viewModel.isPrivateBrowsingEnabled ? Color.purple : Color.purple.opacity(0.2))
                            )
                            .frame(width: 28, height: 28)
                    }
                    
                    // Use a custom UITextField that selects all text when focused
                    SelectAllTextField(text: $urlText, onSubmit: {
                        viewModel.navigateTo(urlString: urlText)
                    })
                    .frame(height: 36)
                    .disableAutocorrection(true)
                    .accessibility(label: Text("Address Bar"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                
                // Navigation buttons
                HStack(spacing: 0) {
                    Spacer()
                    
                    // Back button
                    Button(action: {
                        viewModel.goBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(viewModel.canGoBack ? .blue : .gray)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!viewModel.canGoBack)
                    
                    Spacer()
                    
                    // Forward button
                    Button(action: {
                        viewModel.goForward()
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(viewModel.canGoForward ? .blue : .gray)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!viewModel.canGoForward)
                    
                    Spacer()
                    
                    // Refresh/Stop button
                    Button(action: {
                        if viewModel.isLoading {
                            viewModel.stopLoading()
                        } else {
                            viewModel.reload()
                        }
                    }) {
                        Image(systemName: viewModel.isLoading ? "xmark" : "arrow.clockwise")
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    // Settings button
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 12)
            }
            .background(
                // Translucent background with blur
                Color(UIColor.systemBackground)
                    .opacity(0.85)
                    .background(
                        VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                    )
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: -3)
            .offset(y: calculateToolbarOffset())
            .animation(.spring(response: animationDuration, dampingFraction: 0.7), value: showBottomBar)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: keyboardHeight)
            .onAppear {
                // Set up keyboard observers
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                        let keyboardRectangle = keyboardFrame.cgRectValue
                        
                        // Get animation duration from keyboard notification
                        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
                        
                        withAnimation(.easeOut(duration: duration)) {
                            keyboardHeight = keyboardRectangle.height
                            showBottomBar = true  // Always show the toolbar when keyboard appears
                        }
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { notification in
                    // Get animation duration from keyboard notification
                    let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
                    
                    withAnimation(.easeIn(duration: duration)) {
                        keyboardHeight = 0
                    }
                }
            }
        }
        .navigationBarTitle(viewModel.pageTitle, displayMode: .inline)
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showTabs) {
            TabsView()
                .environmentObject(viewModel)
        }
        .onAppear {
            if viewModel.tabs.isEmpty {
                viewModel.createNewTab()
            } else {
                // Ensure all tabs have proper WebView initialization
                for (index, tab) in viewModel.tabs.enumerated() {
                    if tab.webView == nil {
                        tab.setupWebView(with: viewModel.getWebViewConfiguration(
                            isPrivate: tab.isPrivate
                        ))
                        
                        // Apply user agent
                        if let userAgentString = viewModel.getUserAgentString(), !userAgentString.isEmpty {
                            tab.webView?.customUserAgent = userAgentString
                        }
                    }
                }
            }
            
            // Update URL text when view appears
            urlText = viewModel.activeTab?.url.absoluteString ?? "https://www.google.com"
        }
        .onChange(of: viewModel.activeTabIndex) { newValue in
            // Update URL text when tab changes
            urlText = viewModel.activeTab?.url.absoluteString ?? "https://www.google.com"
            
            // Make sure toolbar is visible when switching tabs
            showBottomBar = true
        }
    }
    
    // Handle scroll events from WebView
    func handleScroll(scrollY: CGFloat, contentHeight: CGFloat, frameHeight: CGFloat) {
        // Don't hide toolbar when keyboard is visible
        if keyboardHeight > 0 {
            if !showBottomBar {
                showBottomBar = true
            }
            return
        }
        
        // Calculate scroll direction
        let scrollingDown = scrollY > lastScrollY
        lastScrollY = scrollY
        
        // Determine if we should show/hide toolbar with smooth animation
        if scrollingDown && scrollY > 60 {
            if showBottomBar {
                withAnimation(.spring(response: animationDuration, dampingFraction: 0.8)) {
                    showBottomBar = false
                }
            }
        } else if !scrollingDown || scrollY < 60 || scrollY > (contentHeight - frameHeight - 20) {
            if !showBottomBar {
                withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                    showBottomBar = true
                }
            }
        }
    }
    
    private func calculateToolbarOffset() -> CGFloat {
        if !showBottomBar {
            return bottomBarHeight // Hide the toolbar
        }
        
        if keyboardHeight <= 0 {
            return 0 // Normal position when no keyboard
        }
        
        // Calculate a position that sits just above the keyboard
        let safeAreaBottom = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
        let screenHeight = UIScreen.main.bounds.height
        let toolbarHeight = bottomBarHeight
        
        // Position the toolbar just above the keyboard with a small gap
        // This uses a calculation based on the screen height to ensure
        // the toolbar is visible without blocking the typing area
        return -keyboardHeight + safeAreaBottom + 10
    }
}

// Extension to create rounded corners on specific sides
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Visual Effect View
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        return UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

// Tab-specific WebView
struct TabWebView: UIViewRepresentable {
    @ObservedObject var tab: BrowserTab
    var onScroll: ((CGFloat, CGFloat, CGFloat) -> Void)? = nil
    
    func makeUIView(context: Context) -> WKWebView {
        if let webView = tab.webView {
            return webView
        } else {
            let webView = WKWebView()
            tab.webView = webView
            
            // Set up scroll view observer for hiding toolbar
            webView.scrollView.delegate = context.coordinator
            
            return webView
        }
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Set delegates if needed
        if webView.navigationDelegate == nil {
            webView.navigationDelegate = context.coordinator
            webView.uiDelegate = context.coordinator
        }
        
        // Make sure scroll view delegate is set
        if webView.scrollView.delegate == nil {
            webView.scrollView.delegate = context.coordinator
        }
        
        // Load URL if webView doesn't have content yet
        if webView.url == nil {
            let request = URLRequest(url: tab.url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
        var parent: TabWebView
        
        init(_ parent: TabWebView) {
            self.parent = parent
        }
        
        // MARK: - UIScrollViewDelegate methods
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            parent.onScroll?(scrollView.contentOffset.y, scrollView.contentSize.height, scrollView.frame.height)
        }
        
        // MARK: - WKNavigationDelegate methods
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.tab.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.tab.isLoading = false
            parent.tab.title = webView.title ?? ""
            parent.tab.canGoBack = webView.canGoBack
            parent.tab.canGoForward = webView.canGoForward
            
            if let url = webView.url {
                parent.tab.url = url
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.tab.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.tab.isLoading = false
        }
        
        // Check if request should be blocked by extensions
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation actions
            decisionHandler(.allow)
        }
        
        // Handle creating new tabs for target="_blank" links
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let frame = navigationAction.targetFrame, frame.isMainFrame {
                return nil
            }
            
            // Get the environment view model through NotificationCenter or using a shared instance
            let viewModel = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController?.view.window?.windowScene?.windows.first?.rootViewController as? UIHostingController<BrowserView>
            
            DispatchQueue.main.async {
                // Get the URL from the navigation action
                if let url = navigationAction.request.url {
                    // Post notification to create a new tab with this URL
                    NotificationCenter.default.post(name: NSNotification.Name("CreateNewTab"), object: nil, userInfo: ["url": url])
                }
            }
            
            return nil
        }
    }
}

// A custom UITextField that selects all text when focused
struct SelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "URL"
    var onSubmit: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.delegate = context.coordinator
        textField.returnKeyType = .go
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .URL
        textField.clearButtonMode = .whileEditing
        textField.backgroundColor = UIColor.systemGray6
        
        // Add some left padding for better text visibility
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: textField.frame.height))
        textField.leftView = leftPaddingView
        textField.leftViewMode = .always
        
        // Center vertically
        textField.contentVerticalAlignment = .center
        
        // Set height constraint to make it compact
        textField.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        // Adjust font size and padding to make it more compact
        textField.font = UIFont.systemFont(ofSize: 15)
        
        // Make corners more rounded like Safari
        textField.layer.cornerRadius = 10
        textField.clipsToBounds = true
        
        // Make sure the text field is properly positioned on iOS
        let spacer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 10))
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.setItems([
            UIBarButtonItem(customView: spacer),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(context.coordinator.doneButtonTapped))
        ], animated: false)
        toolbar.sizeToFit()
        textField.inputAccessoryView = toolbar
        
        return textField
    }
    
    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onSubmit: () -> Void
        
        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self._text = text
            self.onSubmit = onSubmit
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            // Only update if the text actually changed
            if text != textField.text {
                text = textField.text ?? ""
            }
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Delay slightly to ensure proper selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                textField.selectAll(nil)
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            onSubmit()
            return true
        }
        
        // Add some resilience to keyboard handling
        func textFieldDidEndEditing(_ textField: UITextField) {
            // Make sure the text updates when editing ends
            text = textField.text ?? ""
        }
        
        @objc func doneButtonTapped() {
            // Implement the action for the "Done" button
            onSubmit()
        }
    }
} 