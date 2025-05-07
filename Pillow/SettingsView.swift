import SwiftUI
import WebKit

struct SettingsView: View {
    @EnvironmentObject private var viewModel: BrowserViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Settings state
    @State private var selectedUserAgent: UserAgentType = .default
    @State private var customUserAgent: String = ""
    @State private var showAdvancedSettings: Bool = false
    @State private var defaultTabURL: String = "https://www.google.com"
    @State private var selectedSearchEngine: SearchEngineType = .google
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Browser Mode")) {
                    Toggle("Private Browsing", isOn: $viewModel.isPrivateBrowsingEnabled)
                        .onChange(of: viewModel.isPrivateBrowsingEnabled) { newValue in
                            // If enabling private browsing and no private tabs exist, create one
                            if newValue && !viewModel.tabs.contains(where: { $0.isPrivate }) {
                                viewModel.createNewTab(isPrivate: true)
                            } else if !newValue {
                                // If disabling private browsing and active tab is private, switch to a non-private tab
                                if viewModel.activeTab?.isPrivate ?? false {
                                    if let firstNonPrivateIndex = viewModel.tabs.firstIndex(where: { !$0.isPrivate }) {
                                        viewModel.switchToTab(at: firstNonPrivateIndex)
                                    } else {
                                        // If no non-private tabs, create one
                                        viewModel.createNewTab(isPrivate: false)
                                    }
                                }
                            }
                        }
                    
                    if viewModel.isPrivateBrowsingEnabled {
                        Text("New tabs will be opened in private browsing mode. Your browsing history won't be saved.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Private browsing features:", systemImage: "checkmark.shield")
                                .font(.caption)
                                .foregroundColor(.purple)
                            
                            PrivacyFeatureRow(text: "No browsing history saved")
                            PrivacyFeatureRow(text: "Cookies deleted when tab is closed")
                            PrivacyFeatureRow(text: "Enhanced tracker blocking")
                            PrivacyFeatureRow(text: "Stricter privacy settings")
                            
                            Button(action: {
                                // Clear all existing private tabs
                                for index in (0..<viewModel.tabs.count).reversed() where viewModel.tabs[index].isPrivate {
                                    viewModel.closeTab(at: index)
                                }
                                // Create a new private tab
                                viewModel.createNewTab(isPrivate: true)
                            }) {
                                Label("Clear All Private Tabs", systemImage: "trash")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("Tabs")) {
                    Button(action: {
                        viewModel.createNewTab()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Label("New Tab", systemImage: "plus")
                    }
                    
                    Button(action: {
                        viewModel.clearTabHistory()
                    }) {
                        Label("Clear Browsing History", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("User Agent")) {
                    Picker("User Agent", selection: $selectedUserAgent) {
                        ForEach(UserAgentType.allCases, id: \.self) { agent in
                            Text(agent.displayName).tag(agent)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                    .onChange(of: selectedUserAgent) { newValue in
                        if newValue == .custom {
                            customUserAgent = viewModel.customUserAgent
                        } else {
                            viewModel.setUserAgent(type: newValue)
                        }
                    }
                    
                    if selectedUserAgent == .custom {
                        TextField("Custom User Agent", text: $customUserAgent)
                            .font(.system(.body, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section(header: Text("Cache")) {
                    Button(action: {
                        viewModel.clearCache()
                    }) {
                        Text("Clear Browser Cache")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Search Engine")) {
                    Picker("Search Engine", selection: $selectedSearchEngine) {
                        ForEach(SearchEngineType.allCases) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                    .onChange(of: selectedSearchEngine) { newValue in
                        viewModel.setSearchEngine(newValue)
                    }
                    
                    Text(selectedSearchEngine.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Test search
                    Button("Go to Search Homepage") {
                        if let activeTab = viewModel.activeTab {
                            activeTab.loadURL(selectedSearchEngine.baseURL)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                
                Section(header: Text("Default Tab")) {
                    TextField("Default Tab URL", text: $defaultTabURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    Button("Set Current URL as Default") {
                        if let currentURL = viewModel.activeTab?.url.absoluteString {
                            defaultTabURL = currentURL
                        }
                    }
                    .disabled(viewModel.activeTab == nil)
                    
                    Button("Use Search Engine Homepage") {
                        defaultTabURL = selectedSearchEngine.baseURL.absoluteString
                    }
                    
                    Button("Reset to Google") {
                        defaultTabURL = "https://www.google.com"
                    }
                    .foregroundColor(.blue)
                }
                
                Section {
                    Toggle("Advanced Settings", isOn: $showAdvancedSettings)
                }
                
                if showAdvancedSettings {
                    Section(header: Text("Advanced")) {
                        Toggle("Block Pop-ups", isOn: $viewModel.blockPopups)
                        Toggle("JavaScript Enabled", isOn: $viewModel.javascriptEnabled)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Search Engine")
                        Spacer()
                        Text(viewModel.searchEngine.displayName)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Active Tabs")
                        Spacer()
                        Text("\(viewModel.tabs.count)")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Browser Settings")
            .navigationBarItems(trailing: Button("Done") {
                // Apply custom user agent if set
                if selectedUserAgent == .custom && !customUserAgent.isEmpty {
                    viewModel.setCustomUserAgent(customUserAgent)
                }
                
                // Apply default tab URL if valid
                if !defaultTabURL.isEmpty, let _ = URL(string: defaultTabURL) {
                    viewModel.setDefaultTabURL(defaultTabURL)
                }
                
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Initialize settings with current values
                selectedUserAgent = viewModel.userAgentType
                if selectedUserAgent == .custom {
                    customUserAgent = viewModel.customUserAgent
                }
                
                // Initialize default tab URL
                defaultTabURL = viewModel.defaultTabURL
                
                // Initialize search engine selection
                selectedSearchEngine = viewModel.searchEngine
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(BrowserViewModel())
    }
}

// Helper view for privacy features
struct PrivacyFeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.purple)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
} 