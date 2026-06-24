//
//  AppleShapeToolApp.swift
//  AppleShapeToolApp
//
//  Created by Паничкин Кирилл on 28.05.2026.
//

import SwiftUI

@main
struct AppleShapeToolApp: App {
    @StateObject private var store = ShapeStore()

    var body: some Scene {
        WindowGroup("Apple Shape Tool") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 760, minHeight: 560)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
