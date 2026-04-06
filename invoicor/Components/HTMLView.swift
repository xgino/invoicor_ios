// Components/HTMLView.swift
// Renders HTML content inside a WKWebView.
// Scales A4-sized invoice to fit phone screen while keeping proportions.
import SwiftUI
import WebKit

struct HTMLView: UIViewRepresentable {
    let content: String
    var interactive: Bool = false

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = interactive
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = interactive ? 4.0 : 1.0
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        var html = content

        // Inject CSS that renders at original A4 size then scales to fit screen
        let mobileFix = """
        <style>
            body {
                background: white !important;
                padding: 0 !important;
                margin: 0 !important;
                overflow-x: hidden !important;
            }
            .invoice-box, .invoice {
                box-shadow: none !important;
                min-height: auto !important;
            }
        </style>
        <meta name="viewport" content="width=800">
        """

        // Inject before </head>
        if html.lowercased().contains("</head>") {
            html = html.replacingOccurrences(of: "</head>", with: "\(mobileFix)</head>")
        } else {
            html = "\(mobileFix)\(html)"
        }

        webView.loadHTMLString(html, baseURL: nil)
    }
}
