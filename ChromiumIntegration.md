# Chromium Integration Guide for iOS

## Overview
This guide provides instructions for integrating the Chromium Embedded Framework (CEF) into the Pillow iOS browser app. Since integrating Chromium with iOS requires complex C++ bridging and native code, this document outlines the necessary steps.

## Prerequisites
- Xcode 13.0 or later
- CocoaPods installed
- Basic knowledge of C++ for handling the bridging

## Integration Steps

### 1. Download Chromium Source Code
```bash
# Create a directory for Chromium
mkdir -p ~/chromium
cd ~/chromium

# Download the depot_tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=$PATH:~/chromium/depot_tools

# Get Chromium source
mkdir chromium_src && cd chromium_src
fetch --nohooks ios
cd src
gclient runhooks
```

### 2. Build Chromium for iOS
```bash
# Configure for iOS build
gn args out/ios
```

In the editor that opens, add:
```
target_os = "ios"
ios_enable_code_signing = false
is_component_build = false
is_debug = false
```

Then build:
```bash
ninja -C out/ios chrome
```

### 3. Create a Framework Wrapper
The compiled Chromium needs to be wrapped into a framework that can be imported into your Swift project. This involves:

1. Create a C++ wrapper around the Chromium Content API
2. Expose Objective-C interfaces to bridge with Swift
3. Package the compiled binaries into a framework format

### 4. Integration with the Swift App
In your Xcode project:

1. Add the compiled framework to the project
2. Add necessary bridging headers
3. Configure the build settings to include:
   - Framework search paths
   - Library search paths
   - Other linker flags

## Implementation Details

### C++ to Objective-C Bridge Example
```cpp
// ChromiumBridge.h
#import <Foundation/Foundation.h>

@interface ChromiumBridge : NSObject
- (instancetype)init;
- (void)loadURL:(NSString*)url;
- (UIView*)getView;
@end
```

```cpp
// ChromiumBridge.mm
#import "ChromiumBridge.h"
#include "content/public/browser/browser_thread.h"
#include "chrome/browser/ui/webui/chromeos/login/gaia_screen_handler.h"

@implementation ChromiumBridge {
    // Chromium implementation details
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize Chromium components
    }
    return self;
}

- (void)loadURL:(NSString*)url {
    // Call into Chromium to load the URL
}

- (UIView*)getView {
    // Return the UIView that contains the Chromium rendering
}
@end
```

### Objective-C to Swift Bridge
```swift
// ChromiumWrapper.swift
import UIKit

class ChromiumWrapper {
    private let bridge: ChromiumBridge
    
    init() {
        bridge = ChromiumBridge()
    }
    
    func loadURL(urlString: String) {
        bridge.loadURL(urlString)
    }
    
    func getView() -> UIView {
        return bridge.getView()
    }
}
```

## Limitations and Considerations
1. The build process is complex and can take several hours
2. The framework size is large (100MB+)
3. There may be compatibility issues with different iOS versions
4. Apple's App Store policies may prevent distribution of apps with alternative browser engines outside the EU

## Resources
- [Chromium Project](https://www.chromium.org/)
- [Chromium for iOS Source](https://chromium.googlesource.com/chromium/src/+/master/ios/) 