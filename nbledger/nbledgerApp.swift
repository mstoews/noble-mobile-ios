//
//  nbledgerApp.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI

@main
struct nbledgerApp: App {
    @State private var apiService = APIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(apiService)
        }
    }
}
