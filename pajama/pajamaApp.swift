//
//  sidekickApp.swift
//  pajama
//
//  Created by Jakob Frick @ Radiant AI on 06/01/2024.
//

import AppKit
import SwiftUI


@main
struct pajamaApp: App {
    @State var window : NSWindow?
    
   

    var body: some Scene {
        WindowGroup {
            ZStack {
                ChatView(isPresented: .constant(true))
            }.background(TransparentWindow())
            
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}



class TransparentWindowView: NSView {
  override func viewDidMoveToWindow() {
    window?.backgroundColor = .clear
      
    
    super.viewDidMoveToWindow()
  }
}

struct TransparentWindow: NSViewRepresentable {
   func makeNSView(context: Self.Context) -> NSView { return TransparentWindowView() }
   func updateNSView(_ nsView: NSView, context: Context) { }
}
