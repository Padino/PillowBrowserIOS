import SwiftUI
import WebKit

struct TabsView: View {
    @EnvironmentObject private var viewModel: BrowserViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var gridLayout = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)]
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    // Normal Tabs Section
                    if !viewModel.tabs.filter({ !$0.isPrivate }).isEmpty {
                        VStack(alignment: .leading) {
                            Text("Tabs")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top)
                            
                            LazyVGrid(columns: gridLayout, spacing: 16) {
                                ForEach(Array(viewModel.tabs.enumerated().filter { !$0.element.isPrivate }), 
                                        id: \.element.id) { index, tab in
                                    TabPreviewCard(tab: tab, isActive: viewModel.activeTabIndex == index) {
                                        viewModel.closeTab(at: index)
                                    }
                                    .onTapGesture {
                                        viewModel.switchToTab(at: index)
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                                
                                // New Tab Button Card
                                NewTabCard(isPrivate: false) {
                                    viewModel.createNewTab()
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                            .padding()
                        }
                    } else {
                        VStack(alignment: .center) {
                            Text("No normal tabs open")
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                            
                            Button(action: {
                                viewModel.createNewTab()
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Label("New Tab", systemImage: "plus")
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                    
                    // Private Tabs Section (only show if there are private tabs)
                    if !viewModel.tabs.filter({ $0.isPrivate }).isEmpty {
                        VStack(alignment: .leading) {
                            Text("Private Tabs")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top)
                            
                            LazyVGrid(columns: gridLayout, spacing: 16) {
                                ForEach(Array(viewModel.tabs.enumerated().filter { $0.element.isPrivate }),
                                        id: \.element.id) { index, tab in
                                    TabPreviewCard(tab: tab, isActive: viewModel.activeTabIndex == index) {
                                        viewModel.closeTab(at: index)
                                    }
                                    .onTapGesture {
                                        viewModel.switchToTab(at: index)
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                                
                                // New Private Tab Button Card
                                NewTabCard(isPrivate: true) {
                                    if !viewModel.isPrivateBrowsingEnabled {
                                        viewModel.togglePrivateBrowsing()
                                    }
                                    viewModel.createNewTab(isPrivate: true)
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                            .padding()
                        }
                    }
                    
                    // Private Browsing Section
                    if !viewModel.tabs.filter({ $0.isPrivate }).isEmpty {
                        VStack(alignment: .leading) {
                            Text("Private Browsing")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: {
                                    viewModel.togglePrivateBrowsing()
                                    
                                    if viewModel.isPrivateBrowsingEnabled {
                                        if !viewModel.tabs.contains(where: { $0.isPrivate }) {
                                            viewModel.createNewTab(isPrivate: true)
                                        } else if let firstPrivateTabIndex = viewModel.tabs.firstIndex(where: { $0.isPrivate }) {
                                            viewModel.switchToTab(at: firstPrivateTabIndex)
                                        }
                                    }
                                    
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Label(viewModel.isPrivateBrowsingEnabled ? "Exit Private Browsing" : "Enter Private Browsing", 
                                          systemImage: "eyeglasses")
                                        .foregroundColor(.purple)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                Text("Private tabs will not be saved in your browsing history and will delete all cookies when closed.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Tabs")
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct TabPreviewCard: View {
    let tab: BrowserTab
    let isActive: Bool
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail preview of web content
                ZStack {
                    Rectangle()
                        .fill(tab.isPrivate ? Color.purple.opacity(0.15) : Color.gray.opacity(0.2))
                        .aspectRatio(3/2, contentMode: .fit)
                        .clipShape(RoundedCorner(radius: 8, corners: [.topLeft, .topRight]))
                    
                    if let webView = tab.webView {
                        WebViewSnapshot(webView: webView)
                            .aspectRatio(3/2, contentMode: .fit)
                            .clipShape(RoundedCorner(radius: 8, corners: [.topLeft, .topRight]))
                            .opacity(tab.isPrivate ? 0.9 : 1) // Slightly dim private tabs
                    } else {
                        Image(systemName: tab.isPrivate ? "eyeglasses" : "globe")
                            .font(.system(size: 24))
                            .foregroundColor(tab.isPrivate ? .purple : .blue)
                    }
                    
                    // Privacy indicator for private tabs
                    if tab.isPrivate {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                            Text("Private")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.8))
                        .cornerRadius(10)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    
                    if isActive {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(tab.isPrivate ? Color.purple : Color.blue, lineWidth: 2)
                            .clipShape(RoundedCorner(radius: 8, corners: [.topLeft, .topRight]))
                    }
                }
                
                // Tab info
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title.isEmpty ? "New Tab" : tab.title)
                        .lineLimit(1)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                    
                    Text(tab.url.host ?? tab.url.absoluteString)
                        .lineLimit(1)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tab.isPrivate ? Color(UIColor.systemBackground).opacity(0.95) : Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedCorner(radius: 8, corners: [.bottomLeft, .bottomRight]))
            }
            .background(tab.isPrivate ? Color(UIColor.systemBackground).opacity(0.95) : Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedCorner(radius: 8, corners: .allCorners))
            .shadow(color: tab.isPrivate ? Color.purple.opacity(0.2) : Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Close button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(tab.isPrivate ? Color.purple.opacity(0.7) : Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .frame(width: 24, height: 24)
            }
            .padding(6)
        }
    }
}

struct NewTabCard: View {
    let isPrivate: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    Rectangle()
                        .fill(isPrivate ? Color.purple.opacity(0.15) : Color.blue.opacity(0.1))
                        .aspectRatio(3/2, contentMode: .fit)
                        .clipShape(RoundedCorner(radius: 8, corners: [.topLeft, .topRight]))
                    
                    VStack(spacing: 4) {
                        Image(systemName: isPrivate ? "eyeglasses" : "plus")
                            .font(.system(size: 24))
                            .foregroundColor(isPrivate ? .purple : .blue)
                        
                        if isPrivate {
                            Text("Private")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                Text(isPrivate ? "New Private Tab" : "New Tab")
                    .font(.caption)
                    .foregroundColor(isPrivate ? .purple : .primary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(isPrivate ? Color(UIColor.systemBackground).opacity(0.95) : Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedCorner(radius: 8, corners: [.bottomLeft, .bottomRight]))
            }
            .background(isPrivate ? Color(UIColor.systemBackground).opacity(0.95) : Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedCorner(radius: 8, corners: .allCorners))
            .shadow(color: isPrivate ? Color.purple.opacity(0.2) : Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}

// Helper for WebView snapshot
struct WebViewSnapshot: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Create a snapshot of the webView
        webView.takeSnapshot(with: nil) { image, error in
            guard let snapshot = image, error == nil else { return }
            
            // Create or update image view with the snapshot
            let imageView: UIImageView
            if let existingImageView = uiView.subviews.first as? UIImageView {
                imageView = existingImageView
            } else {
                imageView = UIImageView()
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                uiView.addSubview(imageView)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.topAnchor.constraint(equalTo: uiView.topAnchor),
                    imageView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
                    imageView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
                ])
            }
            
            imageView.image = snapshot
        }
    }
}

struct TabsView_Previews: PreviewProvider {
    static var previews: some View {
        TabsView()
            .environmentObject(BrowserViewModel())
    }
} 