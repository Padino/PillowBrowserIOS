#!/bin/bash

# Script to set up the Pillow browser project

echo "Setting up Pillow iOS browser project..."

# Install CocoaPods if not already installed
if ! command -v pod &> /dev/null; then
    echo "CocoaPods not found. Installing..."
    sudo gem install cocoapods
else
    echo "CocoaPods already installed."
fi

# Install dependencies
echo "Installing dependencies..."
pod install

# Modify project.pbxproj to ensure correct build settings
if [ -f "Pillow.xcodeproj/project.pbxproj" ]; then
    echo "Updating project settings..."
    
    # Backup the project file
    cp Pillow.xcodeproj/project.pbxproj Pillow.xcodeproj/project.pbxproj.backup
    
    # Set development team to be empty and use automatic signing
    sed -i '' 's/DEVELOPMENT_TEAM = .*;/DEVELOPMENT_TEAM = "";/g' Pillow.xcodeproj/project.pbxproj
    sed -i '' 's/CODE_SIGN_STYLE = .*;/CODE_SIGN_STYLE = "Automatic";/g' Pillow.xcodeproj/project.pbxproj
    
    # Set the bundle identifier to a wildcard to allow automatic provisioning
    sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = .*;/PRODUCT_BUNDLE_IDENTIFIER = "com.example.Pillow";/g' Pillow.xcodeproj/project.pbxproj
    
    echo "Project settings updated. Original file backed up as project.pbxproj.backup"
else
    echo "Error: project.pbxproj not found. Are you in the right directory?"
    exit 1
fi

echo "Setup complete. Please open Pillow.xcworkspace in Xcode."
echo "NOTE: You will need to manually select your team in Xcode's Signing & Capabilities tab."
echo "      Make sure to uncheck any capabilities that require special entitlements." 