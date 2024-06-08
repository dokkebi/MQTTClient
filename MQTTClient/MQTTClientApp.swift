//
//  MQTTClientApp.swift
//  MQTTClient
//
//  Created by UniqueStrategy on 5/12/24.
//

import SwiftUI

@main
struct MQTTClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth: 1200, minHeight: 850)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.setContentSize(NSSize(width: 1200, height: 850))
                        window.styleMask = [.titled, .resizable, .closable, .miniaturizable]
                        window.title = "Image Viewer"
                    }
                }

        }
    }
}






