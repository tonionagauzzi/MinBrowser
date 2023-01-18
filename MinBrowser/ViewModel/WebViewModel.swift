//
//  WebViewModel.swift
//  MinBrowser
//
//  Created by Takuto Nakamura on 2022/08/10.
//

import Combine
import Foundation
import WebKit

enum WebDialog {
    case alert(_ message: String)
    case confirm(_ message: String)
    case prompt(_ message: String, _ defaultMessage: String)

    var isAlert: Bool {
        switch self {
        case .alert: return true
        default: return false
        }
    }

    var message: String {
        switch self {
        case .alert(let message):
            return message
        case .confirm(let message):
            return message
        case .prompt(let message, _):
            return message
        }
    }
}

protocol WebViewModelProtocol: ObservableObject {
    var estimatedProgress: Double { get set }
    var progressOpacity: Double { get set }
    var canGoBack: Bool { get set }
    var canGoForward: Bool { get set }
    var inputText: String { get set }
    var showDialog: Bool { get set }
    var webDialog: WebDialog { get set }
    var promptInput: String { get set }
    var showBookmark: Bool { get set }
    var title: String? { get set }
    var url: URL? { get set }
    var hideToolBar: Bool { get set }

    // MARK: Reverse Injection
    func setWebView(_ webView: WKWebView)

    // MARK: Web Action
    func search(with text: String, userDefaults: UserDefaults)
    func goBack()
    func goForward()
    func reload()

    // MARK: JS Alert
    func showAlert(
        _ message: String,
        _ completion: @escaping () -> Void
    )

    // MARK: JS Confirm
    func showConfirm(
        _ message: String,
        _ completion: @escaping (Bool) -> Void
    )

    // MARK: JS Prompt
    func showPrompt(
        _ prompt: String,
        _ defaultText: String?,
        _ completion: @escaping (String?) -> Void
    )

    func dialogOK()
    func dialogCancel()
}

extension WebViewModelProtocol {
    func search(with text: String) {
        search(with: text, userDefaults: UserDefaults.standard)
    }
}

final class WebViewModel: WebViewModelProtocol {
    @Published var estimatedProgress: Double = 0.0
    @Published var progressOpacity: Double = 1.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var inputText: String = ""
    @Published var showDialog: Bool = false
    @Published var webDialog: WebDialog = .alert("")
    @Published var promptInput: String = ""
    @Published var showBookmark: Bool = false
    @Published var title: String? = nil
    @Published var url: URL? = nil
    @Published var hideToolBar: Bool = false

    private weak var webView: WKWebView?
    private var alertHandler: (() -> Void)?
    private var confirmHandler: ((Bool) -> Void)?
    private var promptHandler: ((String?) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Reverse Injection
    @MainActor func setWebView(_ webView: WKWebView) {
        self.webView = webView

        webView.publisher(for: \.estimatedProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.estimatedProgress = value
            }
            .store(in: &cancellables)
        webView.publisher(for: \.isLoading)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.progressOpacity = value ? 1 : 0
            }
            .store(in: &cancellables)
        webView.publisher(for: \.canGoBack)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canGoBack = value
            }
            .store(in: &cancellables)
        webView.publisher(for: \.canGoForward)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canGoForward = value
            }
            .store(in: &cancellables)
        webView.publisher(for: \.title)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.title = value
            }
            .store(in: &cancellables)
        webView.publisher(for: \.url)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.url = value
                if let urlString = value?.absoluteString.removingPercentEncoding {
                    self?.inputText = urlString
                }
            }
            .store(in: &cancellables)
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self,
                                 action: #selector(reloadWebView(_:)),
                                 for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
    }

    @MainActor @objc func reloadWebView(_ sender: UIRefreshControl) {
        webView?.reload()
        sender.endRefreshing()
    }

    // MARK: Web Action
    @MainActor func search(
        with text: String,
        userDefaults: UserDefaults = UserDefaults.standard
    ) {
        guard let webView else { return }
        let key = userDefaults.string(forKey: "search-engine") ?? ""
        let searchEngine = SearchEngine(rawValue: key) ?? .google
        var url: URL? = nil
        if text.isEmpty{
            url = URL(string: searchEngine.url)
        } else if text.match(pattern: #"^https?://"#) {
            url = URLComponents(string: text)?.url
        } else {
            let urlString = searchEngine.urlWithQuery(keywords: text)
            url = URLComponents(string: urlString)?.url
        }
        if let url {
            webView.load(URLRequest(url: url))
        }
    }

    @MainActor func goBack() {
        if let webView, webView.canGoBack {
            webView.goBack()
        }
    }

    @MainActor func goForward() {
        if let webView, webView.canGoForward {
            webView.goForward()
        }
    }

    @MainActor func reload() {
        webView?.reload()
    }

    // MARK: JS Alert
    func showAlert(
        _ message: String,
        _ completion: @escaping () -> Void
    ) {
        alertHandler = completion
        webDialog = .alert(message)
        showDialog = true
    }

    // MARK: JS Confirm
    func showConfirm(
        _ message: String,
        _ completion: @escaping (Bool) -> Void
    ) {
        confirmHandler = completion
        webDialog = .confirm(message)
        showDialog = true
    }

    // MARK: JS Prompt
    func showPrompt(
        _ prompt: String,
        _ defaultText: String?,
        _ completion: @escaping (String?) -> Void
    ) {
        promptHandler = completion
        webDialog = .prompt(prompt, defaultText ?? "")
        showDialog = true
    }

    func dialogOK() {
        switch webDialog {
        case .alert:
            alertHandler?()
        case .confirm:
            confirmHandler?(true)
        case .prompt:
            promptHandler?(promptInput)
        }
    }

    func dialogCancel() {
        switch webDialog {
        case .alert:
            break
        case .confirm:
            confirmHandler?(false)
        case .prompt:
            promptHandler?(nil)
        }
    }
}
