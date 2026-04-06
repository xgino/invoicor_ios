// Screens/InvoiceDetailScreen.swift
// Invoice preview with HTML rendering + action buttons.
// Edit in top-right (draft only). Share as PDF. Status changes with confirmation.
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

    // Confirmation alerts
    @State private var showSentConfirm = false
    @State private var showPaidConfirm = false
    @State private var showStatusPicker = false

    // Share
    @State private var isGeneratingPDF = false

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading invoice...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !errorMessage.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { loadInvoice() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // HTML preview with pinch-to-zoom
                if let html = htmlContent {
                    HTMLView(content: html, interactive: true)
                        .ignoresSafeArea(edges: .horizontal)
                        .padding(.bottom, 70)
                } else {
                    ProgressView("Rendering...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Status toast at top
                if !statusMessage.isEmpty {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(statusMessage).font(.callout)
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: statusMessage)
                }

                // Bottom action bar
                if let inv = invoice {
                    VStack {
                        Spacer()
                        bottomBar(for: inv)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Title + badge
            ToolbarItem(placement: .principal) {
                if let inv = invoice {
                    HStack(spacing: 8) {
                        Text(inv.invoiceNumber).font(.headline)
                        StatusBadge(status: inv.status)
                    }
                }
            }
        }
        .task { loadInvoice() }
        // Confirmation alerts
        .alert("Mark as Sent?", isPresented: $showSentConfirm) {
            Button("Mark Sent") { updateStatus("sent") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This invoice will be marked as sent. You won't be able to edit it after this.")
        }
        .alert("Mark as Paid?", isPresented: $showPaidConfirm) {
            Button("Mark Paid") { updateStatus("paid") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This invoice will be marked as paid.")
        }
        // Status picker — all transitions allowed freely
        .confirmationDialog("Change Status", isPresented: $showStatusPicker) {
            if let inv = invoice {
                let current = inv.status.lowercased()
                if current != "draft" {
                    Button("Draft") { updateStatus("draft") }
                }
                if current != "sent" {
                    Button("Sent") { showSentConfirm = true }
                }
                if current != "paid" {
                    Button("Paid") { showPaidConfirm = true }
                }
                if current != "overdue" {
                    Button("Overdue") { updateStatus("overdue") }
                }
                if current != "cancelled" {
                    Button("Cancelled", role: .destructive) { updateStatus("cancelled") }
                }
            }
            Button("Dismiss", role: .cancel) {}
        }
    }

    // MARK: - Bottom Bar

    private func bottomBar(for inv: Invoice) -> some View {
        HStack(spacing: 12) {
            // Status menu (left side, smaller)
            Button {
                showStatusPicker = true
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: statusIcon(for: inv.status))
                        .font(.body)
                    Text("Status")
                        .font(.caption2)
                }
                .foregroundStyle(.primary)
                .frame(width: 56)
            }

            // Share PDF (center, big prominent button)
            Button {
                sharePDF()
            } label: {
                HStack(spacing: 8) {
                    if isGeneratingPDF {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text("Share")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isGeneratingPDF)

            // Duplicate (right side, smaller)
            Button {
                duplicateInvoice()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.body)
                    Text("Duplicate")
                        .font(.caption2)
                }
                .foregroundStyle(.primary)
                .frame(width: 56)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(.all, edges: .bottom)
        )
        .disabled(isUpdating)
    }

    private func statusIcon(for status: String) -> String {
        switch status.lowercased() {
        case "draft": return "pencil.circle"
        case "sent": return "paperplane.circle"
        case "paid": return "checkmark.circle"
        case "overdue": return "exclamationmark.circle"
        case "cancelled": return "xmark.circle"
        default: return "circle"
        }
    }

    // MARK: - Share as PDF (generated locally from HTML)

    private func sharePDF() {
        guard let html = htmlContent else { return }
        isGeneratingPDF = true

        Task {
            let pdfURL = await generatePDF(from: html)

            await MainActor.run {
                isGeneratingPDF = false
                guard let url = pdfURL else {
                    errorMessage = "Failed to generate PDF"
                    return
                }
                presentShareSheet(url: url)
            }
        }
    }

    /// Converts HTML string to a PDF file using iOS native rendering.
    /// Runs on a background thread, returns the temp file URL.
    private func generatePDF(from html: String) async -> URL? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let renderer = UIPrintPageRenderer()
                let formatter = UIMarkupTextPrintFormatter(markupText: html)

                // A4 paper size in points (72 dpi)
                let pageWidth: CGFloat = 595.28  // 210mm
                let pageHeight: CGFloat = 841.89 // 297mm
                let margin: CGFloat = 0

                let printableRect = CGRect(
                    x: margin, y: margin,
                    width: pageWidth - (margin * 2),
                    height: pageHeight - (margin * 2)
                )
                let paperRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

                renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
                renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
                renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

                let pdfData = NSMutableData()
                UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)

                for i in 0..<renderer.numberOfPages {
                    UIGraphicsBeginPDFPage()
                    renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
                }

                UIGraphicsEndPDFContext()

                let filename = "\(self.invoice?.invoiceNumber ?? "invoice").pdf"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

                do {
                    try pdfData.write(to: tempURL, options: .atomic)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func presentShareSheet(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // After sharing draft → auto-mark as sent
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed, let inv = self.invoice, inv.status.lowercased() == "draft" {
                self.updateStatus("sent")
            }
        }

        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(activityVC, animated: true)
    }

    // MARK: - Load Invoice + HTML

    private func loadInvoice() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                async let invReq = APIClient.shared.request(
                    Invoice.self, method: "GET",
                    path: "/invoices/\(invoiceId)/"
                )
                async let htmlReq = APIClient.shared.requestRaw(
                    path: "/invoices/\(invoiceId)/render/"
                )
                let (fetchedInvoice, fetchedHtml) = try await (invReq, htmlReq)
                await MainActor.run {
                    invoice = fetchedInvoice
                    htmlContent = fetchedHtml
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to load"
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Update Status

    private func updateStatus(_ newStatus: String) {
        isUpdating = true
        Task {
            do {
                let updated = try await APIClient.shared.request(
                    Invoice.self, method: "PUT",
                    path: "/invoices/\(invoiceId)/",
                    body: ["status": newStatus]
                )
                let newHtml = try? await APIClient.shared.requestRaw(
                    path: "/invoices/\(invoiceId)/render/"
                )
                await MainActor.run {
                    invoice = updated
                    if let newHtml { htmlContent = newHtml }
                    isUpdating = false
                    statusMessage = "Marked as \(newStatus.capitalized)"
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { withAnimation { statusMessage = "" } }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = (error as? APIError)?.errorDescription ?? "Failed to update"
                }
            }
        }
    }

    // MARK: - Duplicate

    private func duplicateInvoice() {
        isUpdating = true
        Task {
            do {
                let duplicate = try await APIClient.shared.request(
                    Invoice.self, method: "POST",
                    path: "/invoices/\(invoiceId)/duplicate/"
                )
                let newHtml = try? await APIClient.shared.requestRaw(
                    path: "/invoices/\(duplicate.publicId)/render/"
                )
                await MainActor.run {
                    invoice = duplicate
                    if let newHtml { htmlContent = newHtml }
                    isUpdating = false
                    statusMessage = "Duplicated as \(duplicate.invoiceNumber)"
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { withAnimation { statusMessage = "" } }
            } catch {
                await MainActor.run { isUpdating = false }
            }
        }
    }
}
