//
//  TouchIndicator.swift
//  seenlab
//
//  Debug builds only: `-showTouches YES` draws a soft petrol dot wherever a finger touches the screen, so a
//  screen recording (the app video) shows every tap and swipe in sync. It watches the app's window without
//  taking part in any gesture, and draws in its own pass-through window on top (sheets included).
//  It also stamps the wall clock into the recording: 14 black/white blocks in the top-left corner (1/30 s ticks),
//  so tools/app-video/prep.mjs knows the exact time of every video frame (simctl's video timing drifts).
//  The corner is cut off by the rounded screen corners in every film, so the stamp is never seen.
//

#if DEBUG
import UIKit

enum TouchIndicator {
    private static var overlay: UIWindow?
    private static var clock: Clock?

    /// The time stamp: 14 bits of the 1/30-second tick, drawn every frame.
    private final class Clock: NSObject {
        static let bits = 14
        private var blocks: [CALayer] = []
        private var link: CADisplayLink?

        init(canvas: UIView) {
            super.init()
            let w = 1.5, h = 1.0   // points (4.5 × 3 px on a 3x screen)
            for i in 0..<Clock.bits {
                let l = CALayer()
                l.frame = CGRect(x: Double(i) * w, y: 0, width: w, height: h)
                l.actions = ["backgroundColor": NSNull()]
                canvas.layer.addSublayer(l)
                blocks.append(l)
            }
            link = CADisplayLink(target: self, selector: #selector(tick))
            link?.add(to: .main, forMode: .common)
        }

        @objc private func tick() {
            let v = Int((Date().timeIntervalSince1970 * 30).rounded(.down)) & ((1 << Clock.bits) - 1)
            CATransaction.begin(); CATransaction.setDisableActions(true)
            for (i, l) in blocks.enumerated() { l.backgroundColor = (v >> (Clock.bits - 1 - i)) & 1 == 1 ? UIColor.white.cgColor : UIColor.black.cgColor }
            CATransaction.commit()
        }
    }

    static func install() {
        guard UserDefaults.standard.bool(forKey: "showTouches"), overlay == nil else { return }
        // wait for the first window to exist
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                  let main = scene.windows.first(where: { $0.windowLevel == .normal }) else { install(); return }
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 10
            window.isUserInteractionEnabled = false
            window.backgroundColor = .clear
            window.rootViewController = UIViewController()
            window.rootViewController?.view.backgroundColor = .clear
            window.isHidden = false
            overlay = window
            main.addGestureRecognizer(Watcher(canvas: window))
            clock = Clock(canvas: window)
        }
    }

    /// Sees every touch in the window and never recognizes, so the app's own gestures are untouched.
    private final class Watcher: UIGestureRecognizer {
        private weak var canvas: UIView?
        private var dots: [UITouch: CALayer] = [:]

        init(canvas: UIView) {
            self.canvas = canvas
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            for t in touches {
                let dot = CALayer()
                dot.bounds = CGRect(x: 0, y: 0, width: 46, height: 46)
                dot.cornerRadius = 23
                dot.backgroundColor = UIColor(red: 15 / 255, green: 110 / 255, blue: 110 / 255, alpha: 0.32).cgColor
                dot.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
                dot.borderWidth = 2.5
                dot.shadowColor = UIColor.black.cgColor
                dot.shadowOpacity = 0.18
                dot.shadowRadius = 6
                dot.position = t.location(in: canvas)
                canvas?.layer.addSublayer(dot)
                let pop = CABasicAnimation(keyPath: "transform.scale")
                pop.fromValue = 0.6; pop.toValue = 1; pop.duration = 0.12
                dot.add(pop, forKey: "pop")
                dots[t] = dot
            }
            state = .possible
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            for t in touches { dots[t]?.position = t.location(in: canvas) }
            CATransaction.commit()
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches) }

        private func lift(_ touches: Set<UITouch>) {
            for t in touches {
                guard let dot = dots.removeValue(forKey: t) else { continue }
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.35)
                CATransaction.setCompletionBlock { dot.removeFromSuperlayer() }
                dot.opacity = 0
                dot.transform = CATransform3DMakeScale(1.6, 1.6, 1)
                CATransaction.commit()
            }
            if dots.isEmpty { state = .failed }
        }

        override func reset() { super.reset() }
    }
}
#endif
