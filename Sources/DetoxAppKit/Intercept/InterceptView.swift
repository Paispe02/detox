import AVKit
import Combine
import SwiftUI

/// One thing owns the whole screen: the video, or a calm pause with the night arc and breathing.
struct InterceptView: View {
    let content: InterceptContent
    let shownAt: Date
    let onClose: () -> Void

    @State private var videoEnded = false
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var canClose: Bool {
        InterceptTiming.canClose(elapsed: now.timeIntervalSince(shownAt), videoEnded: videoEnded)
    }

    private var secondsLeft: Int {
        max(0, Int(ceil(InterceptTiming.minimumSeconds - now.timeIntervalSince(shownAt))))
    }

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()
            switch content {
            case .video(let url, _):
                VideoPlayerView(url: url) { videoEnded = true }.ignoresSafeArea()
            case .fallback(let phrase, _, let opensAt, let progress):
                CalmPause(phrase: phrase, opensAt: opensAt, progress: progress, now: now)
            }
            VStack {
                HStack {
                    Text(content.blockName).font(Theme.title(15)).foregroundStyle(Theme.ivorySecondary)
                    Spacer()
                    if canClose {
                        Button("Cerrar", action: onClose)
                            .keyboardShortcut(.defaultAction)
                            .controlSize(.large)
                    } else {
                        Text("Podrás cerrar en \(secondsLeft) s")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(Theme.ivoryTertiary)
                    }
                }
                .padding(28)
                Spacer()
            }
        }
        .foregroundStyle(Theme.ivory)
        .preferredColorScheme(.dark)
        .onReceive(ticker) { now = $0 }
    }
}

struct CalmPause: View {
    let phrase: String
    let opensAt: Date?
    let progress: (current: Int, total: Int)?
    let now: Date

    var body: some View {
        VStack(spacing: 36) {
            BreathingRing()
            Text(phrase)
                .font(Theme.title(34))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 760)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                if let opensAt {
                    Text("Se abre a las \(Formatting.clock(opensAt)) · faltan \(Formatting.remaining(from: now, to: opensAt))")
                        .font(.title3)
                        .foregroundStyle(Theme.ivorySecondary)
                }
                if let p = progress {
                    Text("Noche \(p.current) de \(p.total)")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .padding(48)
    }
}

/// Inhale 4 s, hold 4 s, exhale 6 s. Reduced motion: a still ring with the cue in words.
struct BreathingRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private func phase(at t: TimeInterval) -> (scale: CGFloat, label: String) {
        let c = t.truncatingRemainder(dividingBy: 14)
        if c < 4 { return (0.6 + 0.4 * ease(c / 4), "Inspira") }
        if c < 8 { return (1, "Mantén") }
        return (1 - 0.4 * ease((c - 8) / 6), "Suelta")
    }

    private func ease(_ x: Double) -> CGFloat { CGFloat(0.5 - cos(x * .pi) / 2) }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let p = phase(at: reduceMotion ? 5 : ctx.date.timeIntervalSince(start))
            ZStack {
                Circle().stroke(Theme.hairline, lineWidth: 1).frame(width: 220, height: 220)
                Circle()
                    .stroke(Theme.gold, lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .scaleEffect(p.scale)
                Circle()
                    .fill(Theme.gold.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .scaleEffect(p.scale)
                Text(reduceMotion ? "Inspira 4 · mantén 4 · suelta 6" : p.label)
                    .font(Theme.title(reduceMotion ? 14 : 20))
                    .foregroundStyle(Theme.ivorySecondary)
            }
        }
        .accessibilityLabel("Respiración guiada: inspira cuatro segundos, mantén cuatro, suelta seis")
    }
}

struct VideoPlayerView: NSViewRepresentable {
    let url: URL
    let onEnd: () -> Void

    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.controlsStyle = .none
        v.videoGravity = .resizeAspect
        let player = AVPlayer(url: url)
        v.player = player
        context.coordinator.observe(player, onEnd: onEnd)
        player.play()
        return v
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        nsView.player?.pause()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var token: NSObjectProtocol?
        func observe(_ player: AVPlayer, onEnd: @escaping () -> Void) {
            token = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                           object: player.currentItem, queue: .main) { _ in onEnd() }
        }
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
}

/// For design review renders only.
public enum InterceptPreview {
    public static func calm(blockName: String, opensAt: Date?, progress: (Int, Int)?) -> some View {
        InterceptView(content: .fallback(phrase: "El impulso dura unos segundos. Respira y deja que pase.", blockName: blockName,
                                         opensAt: opensAt, progress: progress.map { ($0.0, $0.1) }),
                      shownAt: Date(), onClose: {})
    }
}
