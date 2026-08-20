// Screens/Auth/SplashScreen.swift
// Polished, fast splash for Invoicor.
// An invoice "writes itself" (lines draw in, then a checkmark), the wordmark
// fades in, and the screen dismisses as soon as the app signals it's ready
// (or after a short safety cap) — no fixed dead-time.
//
// Usage stays the same:  SplashScreen(onFinished: { ... })
// Optional: pass `isReady` if you have a real "app loaded" signal (auth check,
// initial fetch, etc). When it flips true, the splash leaves immediately after
// the intro finishes. If you don't have one, leave it out and it uses the cap.

import SwiftUI

struct SplashScreen: View {
    let onFinished: () -> Void

    /// Flip this to true when your app has finished its startup work.
    /// Defaults to true so the splash leaves on its own if you don't wire it up.
    var isReady: Bool = true

    // Timing — deliberately short. Intro finishes ~1.0s; hard cap 1.6s.
    private let introDuration: Double = 1.0
    private let safetyCap: Double = 1.6

    // Animation state
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var lineProgress: CGFloat = 0     // drives the "writing" lines
    @State private var checkProgress: CGFloat = 0    // drives the checkmark stroke
    @State private var textOpacity: Double = 0
    @State private var gradientShift = false
    @State private var didFinish = false             // guard against double-calling onFinished

    var body: some View {
        ZStack {
            // Calm animated gradient — brand blues, gently drifting.
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.12, blue: 0.32),
                    Color(red: 0.06, green: 0.16, blue: 0.42),
                    Color(red: 0.10, green: 0.22, blue: 0.52),
                ],
                startPoint: gradientShift ? .topLeading : .bottomLeading,
                endPoint: gradientShift ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: gradientShift)

            VStack(spacing: 22) {
                // Invoice mark that draws itself, inside a rounded card with a soft glow.
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.blue.opacity(0.35), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 90
                            )
                        )
                        .frame(width: 170, height: 170)
                        .opacity(logoOpacity * 0.7)

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.blue, Color(red: 0.15, green: 0.4, blue: 0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: .blue.opacity(0.45), radius: 22, y: 10)
                        .overlay(
                            InvoiceMark(lineProgress: lineProgress, checkProgress: checkProgress)
                                .padding(22)
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("Invoicor")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Professional invoicing made simple")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .opacity(textOpacity)
            }
        }
        .onAppear { runIntro() }
        // If a real readiness signal arrives after the intro, leave promptly.
        .onChange(of: isReady) { _, ready in
            if ready { finishWhenReady() }
        }
    }

    // MARK: - Sequencing

    private func runIntro() {
        gradientShift = true

        // Card scales/fades in.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        // Invoice lines "write" in.
        withAnimation(.easeInOut(duration: 0.55).delay(0.18)) {
            lineProgress = 1.0
        }
        // Checkmark strokes on after the lines.
        withAnimation(.easeOut(duration: 0.35).delay(0.7)) {
            checkProgress = 1.0
        }
        // Wordmark fades up.
        withAnimation(.easeOut(duration: 0.45).delay(0.5)) {
            textOpacity = 1.0
        }

        // After the intro, either leave now (if ready) or wait for the cap.
        DispatchQueue.main.asyncAfter(deadline: .now() + introDuration) {
            if isReady { finish() }
        }
        // Safety cap so we never hang if `isReady` is never set.
        DispatchQueue.main.asyncAfter(deadline: .now() + safetyCap) {
            finish()
        }
    }

    private func finishWhenReady() {
        // Only leave once the intro has had time to play.
        DispatchQueue.main.asyncAfter(deadline: .now() + introDuration) {
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        // Gentle fade-out hand-off feels smoother than a hard cut.
        withAnimation(.easeIn(duration: 0.25)) {
            logoOpacity = 0
            textOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onFinished()
        }
    }
}

// MARK: - Invoice mark (self-drawing document + checkmark)

private struct InvoiceMark: View {
    var lineProgress: CGFloat
    var checkProgress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                // Document text lines, drawn left-to-right via trim.
                VStack(alignment: .leading, spacing: h * 0.13) {
                    invoiceLine(width: w * 0.85)
                    invoiceLine(width: w * 0.65)
                    invoiceLine(width: w * 0.75)
                    invoiceLine(width: w * 0.45)
                }
                .frame(width: w, height: h, alignment: .top)

                // Checkmark, bottom-right, strokes on last.
                CheckShape()
                    .trim(from: 0, to: checkProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: max(2, w * 0.09), lineCap: .round, lineJoin: .round))
                    .frame(width: w * 0.4, height: w * 0.4)
                    .position(x: w * 0.78, y: h * 0.8)
            }
        }
    }

    private func invoiceLine(width: CGFloat) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.9))
            .frame(width: width, height: 4)
            .scaleEffect(x: lineProgress, y: 1, anchor: .leading)
            .opacity(Double(lineProgress))
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - rect.height * 0.15))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.minY + rect.height * 0.15))
        return p
    }
}

#Preview {
    SplashScreen(onFinished: {})
}
