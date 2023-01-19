//
//  WKWebView+Extension.swift
//  MinBrowser
//
//  Created by Takuto Nakamura on 2022/04/02.
//

import WebKit

extension WKWebView: WKScriptMessageHandler {
    public func enableConsoleLog() {
        self.configuration.userContentController.add(self, name: "logging")
        let js = """
        var console = {
          log: function(msg) {
            window.webkit.messageHandlers.logging.postMessage(msg);
          }
        };
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        self.configuration.userContentController.addUserScript(script)
    }

    nonisolated public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Only a single line of text can be output.
        DebugLog(WKWebView.self, "\(message.body)")
    }
}

