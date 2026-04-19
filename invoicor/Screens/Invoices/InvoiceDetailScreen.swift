// Screens/Invoices/InvoiceDetailScreen.swift
// Full-page invoice preview with HTML rendering + action bar.
// Uses SubPageLayout for consistent back button and no nav chrome.

import SwiftUI
import WebKit

struct InvoiceDetailScreen: View {
    let invoiceId: String

    @Environment(\.dismiss) private var dismiss
    @State private var invoice: Invoice? = nil
    @State private var htmlContent: String? = nil
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var isUpdating = false
    @State private var statusMessage = ""
    @State private var showSentConfirm = false
    @State private var showPaidConfirm = false
    @State private var showStatusPicker = false
    @State private var isGeneratingPDF = false
    @State private var showEditForm = false
    @State private var showDuplicateForm = false

    // A4 aspect ratio: 210mm / 297mm
    private let a4Ratio: CGFloat = 210.0 / 297.0

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold)).foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6)).clipShape(Circle())
                }

                if let inv = invoice {
                    HStack(spacing: 8) {
                        Text(inv.invoiceNumber).font(.headline)
                        StatusBadge(status: inv.status)
                    }
                }

                Spacer()

                if let inv = invoice, inv.status == "draft" {
                    Button { showEditForm = true } label: {
                        Text("Edit").font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)

            // Content
            ZStack {
                // Neutral background so the invoice "page" floats on it
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading invoice…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !errorMessage.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                        Text(errorMessage).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { Task { await loadInvoice() } }.buttonStyle(.borderedProminent)
                    }.padding(40)
                } else if let html = htmlContent {
                    GeometryReader { geo in
                        let available = geo.size
                        let fitWidth = min(available.width - 24, available.height * a4Ratio)
                        let fitHeight = fitWidth / a4Ratio

                        InvoicePreviewView(html: html)
                            .frame(width: fitWidth, height: fitHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                            .position(x: available.width / 2, y: available.height / 2)
                    }
                } else {
                    ProgressView("Rendering…").frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Status toast
                if !statusMessage.isEmpty {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(statusMessage).font(.callout)
                        }
                        .foregroundStyle(.white).padding(12)
                        .background(Color.green).clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // Bottom action bar
            if invoice != nil {
                bottomBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await loadInvoice() }
        .fullScreenCover(isPresented: $showEditForm, onDismiss: { Task { await loadInvoice() } }) {
            if let inv = invoice { CreateInvoiceScreen(isPresented: $showEditForm, editInvoice: inv) }
        }
        .fullScreenCover(isPresented: $showDuplicateForm) {
            if let inv = invoice { CreateInvoiceScreen(isPresented: $showDuplicateForm, duplicateFrom: inv) }
        }
        .alert("Mark as Sent?", isPresented: $showSentConfirm) {
            Button("Mark Sent") { updateStatus("sent") }; Button("Cancel", role: .cancel) {}
        } message: { Text("You won't be able to edit it after this.") }
        .alert("Mark as Paid?", isPresented: $showPaidConfirm) {
            Button("Mark Paid") { updateStatus("paid") }; Button("Cancel", role: .cancel) {}
        } message: { Text("This invoice will be marked as paid.") }
        .confirmationDialog("Change Status", isPresented: $showStatusPicker) {
            if let inv = invoice {
                let s = inv.status.lowercased()
                if s != "draft" { Button("Draft") { updateStatus("draft") } }
                if s != "sent" { Button("Sent") { showSentConfirm = true } }
                if s != "paid" { Button("Paid") { showPaidConfirm = true } }
                if s != "overdue" { Button("Overdue") { updateStatus("overdue") } }
                if s != "cancelled" { Button("Cancelled", role: .destructive) { updateStatus("cancelled") } }
            }
            Button("Dismiss", role: .cancel) {}
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button { showStatusPicker = true } label: {
                    VStack(spacing: 3) {
                        Image(systemName: statusIcon).font(.body)
                        Text("Status").font(.caption2)
                    }.foregroundStyle(.primary).frame(width: 52)
                }

                Button { sharePDF() } label: {
                    HStack(spacing: 8) {
                        if isGeneratingPDF { ProgressView().tint(.white) }
                        else { Image(systemName: "square.and.arrow.up") }
                        Text("Share").fontWeight(.semibold)
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.blue).clipShape(RoundedRectangle(cornerRadius: 10))
                }.disabled(isGeneratingPDF)

                Button { showDuplicateForm = true } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "doc.on.doc").font(.body)
                        Text("Copy").font(.caption2)
                    }.foregroundStyle(.primary).frame(width: 52)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
        .disabled(isUpdating)
    }

    private var statusIcon: String {
        switch invoice?.status.lowercased() ?? "" {
        case "draft": return "pencil.circle"; case "sent": return "paperplane.circle"
        case "paid": return "checkmark.circle"; case "overdue": return "exclamationmark.circle"
        case "cancelled": return "xmark.circle"; default: return "circle"
        }
    }

    // MARK: - Share PDF

    private func sharePDF() {
        guard let html = htmlContent else { return }
        isGeneratingPDF = true
        Task {
            let url = await generatePDF(from: html)
            await MainActor.run {
                isGeneratingPDF = false
                guard let url else { errorMessage = "Failed to generate PDF"; return }
                presentShareSheet(url: url)
            }
        }
    }

    /// Generate a single-page A4 PDF using WKWebView.
    /// WKWebView renders CSS mm units at 96dpi (1mm = 3.7795px),
    /// so 210mm x 297mm = 793.7px x 1122.5px.
    /// We size the webview to match, then createPDF captures the full content.
    private func generatePDF(from html: String) async -> URL? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let cssWidth: CGFloat = 794
                let cssHeight: CGFloat = 1123

                let config = WKWebViewConfiguration()
                let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: cssWidth, height: cssHeight), configuration: config)
                webView.isOpaque = false
                webView.backgroundColor = .white

                var pdfHTML = html
                if pdfHTML.contains("<head>") {
                    pdfHTML = pdfHTML.replacingOccurrences(
                        of: "<head>",
                        with: "<head><meta name=\"viewport\" content=\"width=\(Int(cssWidth)), initial-scale=1.0, shrink-to-fit=no\">"
                    )
                }

                let delegate = PDFNavigationDelegate {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let pdfConfig = WKPDFConfiguration()
                        pdfConfig.rect = CGRect(x: 0, y: 0, width: cssWidth, height: cssHeight)

                        webView.createPDF(configuration: pdfConfig) { result in
                            switch result {
                            case .success(let data):
                                let name = "\(self.invoice?.invoiceNumber ?? "invoice").pdf"
                                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                                do {
                                    try data.write(to: url, options: .atomic)
                                    continuation.resume(returning: url)
                                } catch {
                                    continuation.resume(returning: nil)
                                }
                            case .failure:
                                continuation.resume(returning: nil)
                            }
                        }
                    }
                }
                webView.navigationDelegate = delegate
                objc_setAssociatedObject(webView, "pdfDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)

                webView.loadHTMLString(pdfHTML, baseURL: nil)
            }
        }
    }

    private func presentShareSheet(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            if completed, let inv = self.invoice, inv.status.lowercased() == "draft" { self.updateStatus("sent") }
        }
        var presenter = root
        while let p = presenter.presentedViewController { presenter = p }
        presenter.present(vc, animated: true)
    }

    // MARK: - Load / Status

    private func loadInvoice() async {
        isLoading = true; errorMessage = ""
        do {
            let inv = try await APIClient.shared.request(Invoice.self, method: "GET", path: "/invoices/\(invoiceId)/")
            let html = try await APIClient.shared.requestRaw(path: "/invoices/\(invoiceId)/render/")
            await MainActor.run { invoice = inv; htmlContent = html; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load"; isLoading = false }
        }
    }

    private func updateStatus(_ newStatus: String) {
        isUpdating = true
        Task {
            do {
                let updated = try await APIClient.shared.request(Invoice.self, method: "PUT", path: "/invoices/\(invoiceId)/", body: ["status": newStatus])
                let newHtml = try? await APIClient.shared.requestRaw(path: "/invoices/\(invoiceId)/render/")
                await MainActor.run {
                    invoice = updated; if let newHtml { htmlContent = newHtml }
                    isUpdating = false; statusMessage = "Marked as \(newStatus.capitalized)"
                    if newStatus == "paid" { ReviewManager.invoicePaid() }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { withAnimation { statusMessage = "" } }
            } catch {
                await MainActor.run { isUpdating = false; errorMessage = (error as? APIError)?.errorDescription ?? "Failed to update" }
            }
        }
    }
}

// MARK: - PDF Navigation Delegate
private class PDFNavigationDelegate: NSObject, WKNavigationDelegate {
    let onFinished: () -> Void

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinished()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onFinished()
    }
}

// MARK: - Invoice Preview (hidden indicators, no white bleed, fits on open)
/// Renders the invoice HTML at its native 794px width, then uses a CSS transform
/// to visually scale it down to fit the preview frame. This is a pure visual
/// shrink -- no re-layout, no font reflow, pixel-perfect match to the template.
private struct InvoicePreviewView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 5.0

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let tag = html.hashValue
        if webView.tag != tag {
            webView.tag = tag

            let frameWidth = webView.frame.width > 0 ? webView.frame.width : UIScreen.main.bounds.width - 24
            let contentWidth: CGFloat = 794   // 210mm at 96dpi
            let contentHeight: CGFloat = 1123  // 297mm at 96dpi
            let scale = frameWidth / contentWidth
            let scaledHeight = contentHeight * scale

            let scaleCSS = """
            <style>
                html { width: \(Int(scaledHeight * (contentWidth / contentHeight)))px;
                       height: \(Int(scaledHeight))px; overflow: hidden; }
                body { width: \(Int(contentWidth))px; height: \(Int(contentHeight))px;
                       margin: 0; padding: 0;
                       transform: scale(\(scale)); transform-origin: top left; }
            </style>
            """

            var previewHTML = html
            if previewHTML.contains("<head>") {
                previewHTML = previewHTML.replacingOccurrences(
                    of: "<head>",
                    with: "<head>\(scaleCSS)"
                )
            }

            webView.loadHTMLString(previewHTML, baseURL: nil)
        }
    }
}
