	//
//  ContentView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(APIService.self) private var apiService
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("authToken") private var authToken = ""
    @AppStorage("refreshToken") private var refreshToken = ""
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("companyName") private var companyName = ""

    var body: some View {
        if isLoggedIn {
            MainView(
                userName: userName,
                userEmail: userEmail,
                companyName: companyName,
                onLogout: {
                    apiService.token = ""
                    apiService.refreshToken = ""
                    isLoggedIn = false
                    authToken = ""
                    refreshToken = ""
                    userName = ""
                    userEmail = ""
                    companyName = ""
                }
            )
        } else {
            LoginView { response in
                apiService.token = response.token
                apiService.refreshToken = response.refreshToken
                authToken = response.token
                refreshToken = response.refreshToken
                userName = response.userName
                userEmail = response.userEmail
                companyName = response.companyName
                isLoggedIn = true
            }
        }
    }
}

#Preview {
    ContentView()
}
