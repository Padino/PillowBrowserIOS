platform :ios, '14.0'

target 'Pillow' do
  use_frameworks!
  
  # For integrating Chromium
  # Note: In a real implementation, you would need to use a compiled Chromium framework
  # There's no official CocoaPods distribution of Chromium, so this would require manual integration
  # This placeholder pod will be replaced with actual integration steps
  
  # Networking utilities
  pod 'Alamofire', '~> 5.4'
  
  # UI components
  pod 'SnapKit', '~> 5.0'
  
  target 'PillowTests' do
    inherit! :search_paths
  end

  target 'PillowUITests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end 