// Screens/Auth/SplashScreen.swift
// Animated splash with gradient background, floating particles,
// app logo scale + fade animation.

import SwiftUI

struct SplashScreen: View {
    let onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var gradientStart = UnitPoint.topLeading
    @State private var gradientEnd = UnitPoint.bottomTrailing
    @State private var particleOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.3),
                    Color(red: 0.05, green: 0.15, blue: 0.4),
                    Color(red: 0.1, green: 0.2, blue: 0.5),
                ],
                startPoint: gradientStart,
                endPoint: gradientEnd
            )
            .ignoresSafeArea()

            // Subtle floating particles
            GeometryReader { geo in
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(Double.random(in: 0.03...0.08)))
                        .frame(width: CGFloat.random(in: 40...120))
                        .offset(
                            x: CGFloat.random(in: -50...geo.size.width),
                            y: CGFloat.random(in: -50...geo.size.height) + particleOffset * CGFloat(i % 3 == 0 ? -1 : 1) * 20
                        )
                        .blur(radius: CGFloat.random(in: 10...30))
                }
            }

            // Logo + text
            VStack(spacing: 20) {
                // Icon with glow
                ZStack {
                    // Glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.blue.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(logoScale * 1.2)
                        .opacity(logoOpacity * 0.6)

                    // App logo
                    Group {
                        if UIImage(named: "AppLogo") != nil {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .shadow(color: .blue.opacity(0.4), radius: 20, y: 8)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App name
                VStack(spacing: 6) {
                    Text("Invoicor")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Professional invoicing made simple")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                gradientStart = .bottomTrailing
                gradientEnd = .topLeading
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                particleOffset = 1
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onFinished()
            }
        }
    }
}
