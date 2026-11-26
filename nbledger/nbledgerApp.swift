//
//  nbledgerApp.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI

@main
struct nbledgerApp: App {
    @State private var apiService: APIService

    init() {
        // Seed or clear the test-only demo session before anything reads defaults.
        DemoMode.prepareDefaults()
        _apiService = State(initialValue: DemoMode.isEnabled
            ? APIService(session: DemoMode.makeSession())
            : APIService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(apiService)
        }
    }
}
