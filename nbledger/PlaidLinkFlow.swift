//
//  PlaidLinkFlow.swift
//  nbledger
//
//  Created by Murray Toews on 4/4/26.
//

import SwiftUI
import LinkKit

struct PlaidLinkFlow: UIViewControllerRepresentable {
    let linkToken: String
    let onSuccess: (String) -> Void
    let onExit: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground

        var linkConfiguration = LinkTokenConfiguration(token: linkToken) { success in
            onSuccess(success.publicToken)
        }
        linkConfiguration.onExit = { _ in
            onExit()
        }

        let result = Plaid.create(linkConfiguration)
        switch result {
        case .success(let handler):
            DispatchQueue.main.async {
                handler.open(presentUsing: .viewController(vc))
            }
        case .failure:
            DispatchQueue.main.async {
                onExit()
            }
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
