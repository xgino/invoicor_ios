// Screens/Invoices/InvoiceDetailScreen.swift
// Full-page invoice preview with HTML rendering + action bar.
// Uses SubPageLayout for consistent back button and no nav chrome.

import SwiftUI

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
                if isLoading {
                    ProgressView("Loading invoice…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !errorMessage.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                        Text(errorMessage).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { Task { await loadInvoice() } }.buttonStyle(.borderedProminent)
                    }.padding(40)
                } else if let html = htmlContent {
                    HTMLView(content: html, interactive: true)
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

    private func generatePDF(from html: String) async -> URL? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let renderer = UIPrintPageRenderer()
                let formatter = UIMarkupTextPrintFormatter(markupText: html)
                let pw: CGFloat = 595.28, ph: CGFloat = 841.89
                let paper = CGRect(x: 0, y: 0, width: pw, height: ph)
                renderer.setValue(NSValue(cgRect: paper), forKey: "paperRect")
                renderer.setValue(NSValue(cgRect: paper), forKey: "printableRect")
                renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
                let data = NSMutableData()
                UIGraphicsBeginPDFContextToData(data, paper, nil)
                for i in 0..<renderer.numberOfPages {
                    UIGraphicsBeginPDFPage()
                    renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
                }
                UIGraphicsEndPDFContext()
                let name = "\(self.invoice?.invoiceNumber ?? "invoice").pdf"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                do { try data.write(to: url, options: .atomic); continuation.resume(returning: url) }
                catch { continuation.resume(returning: nil) }
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
            async let invReq = APIClient.shared.request(Invoice.self, method: "GET", path: "/invoices/\(invoiceId)/")
            async let htmlReq = APIClient.shared.requestRaw(path: "/invoices/\(invoiceId)/render/")
            let (inv, html) = try await (invReq, htmlReq)
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
