import SwiftUI

struct ExtensionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var extensionManager = ExtensionManager.shared
    @State private var selectedExtension: BrowserExtension?
    @State private var showExtensionDetails = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Installed Extensions")) {
                    if extensionManager.installedExtensions.isEmpty {
                        Text("No extensions installed")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(extensionManager.installedExtensions, id: \.id) { ext in
                            ExtensionRow(extension: ext, isInstalled: true) {
                                selectedExtension = ext
                                showExtensionDetails = true
                            }
                        }
                    }
                }
                
                Section(header: Text("Available Extensions")) {
                    ForEach(extensionManager.availableExtensions.filter { ext in
                        !extensionManager.installedExtensions.contains { $0.id == ext.id }
                    }, id: \.id) { ext in
                        ExtensionRow(extension: ext, isInstalled: false) {
                            selectedExtension = ext
                            showExtensionDetails = true
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    Text("Extensions can enhance your browsing experience by adding functionality like ad-blocking, dark mode, and more.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Extensions")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showExtensionDetails) {
                if let ext = selectedExtension {
                    ExtensionDetailView(extension: ext)
                }
            }
            .onAppear {
                // Make sure extension manager is initialized
                extensionManager.initialize()
            }
        }
    }
}

struct ExtensionRow: View {
    let `extension`: BrowserExtension
    let isInstalled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                `extension`.icon.toImage()
                    .foregroundColor(isInstalled ? .blue : .gray)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(`extension`.name)
                        .font(.headline)
                    
                    Text(`extension`.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isInstalled {
                    Toggle("", isOn: .constant(`extension`.isEnabled))
                        .labelsHidden()
                        .onChange(of: `extension`.isEnabled) { _ in
                            ExtensionManager.shared.toggleExtension(withID: `extension`.id)
                        }
                } else {
                    Button(action: {
                        ExtensionManager.shared.installExtension(`extension`)
                    }) {
                        Text("Install")
                            .font(.caption)
                            .bold()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

struct ExtensionDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    let `extension`: BrowserExtension
    
    var isInstalled: Bool {
        ExtensionManager.shared.installedExtensions.contains { $0.id == `extension`.id }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 16) {
                        `extension`.icon.toImage()
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text(`extension`.name)
                            .font(.title)
                        
                        Text(`extension`.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                Section(header: Text("Details")) {
                    DetailRow(title: "Version", value: `extension`.version)
                    DetailRow(title: "Author", value: `extension`.author)
                }
                
                Section(header: Text("Permissions")) {
                    PermissionRow(title: "Inject Scripts", isAllowed: `extension`.canInjectScripts)
                    PermissionRow(title: "Modify Requests", isAllowed: `extension`.canModifyRequests)
                    PermissionRow(title: "Modify Headers", isAllowed: `extension`.canModifyHeaders)
                    PermissionRow(title: "Access User Data", isAllowed: `extension`.canAccessUserData)
                }
                
                Section {
                    if isInstalled {
                        Button(action: {
                            ExtensionManager.shared.uninstallExtension(withID: `extension`.id)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Text("Uninstall")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    } else {
                        Button(action: {
                            ExtensionManager.shared.installExtension(`extension`)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Text("Install")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Extension Details")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct PermissionRow: View {
    let title: String
    let isAllowed: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isAllowed {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
            }
        }
    }
}

struct ExtensionsView_Previews: PreviewProvider {
    static var previews: some View {
        ExtensionsView()
    }
} 