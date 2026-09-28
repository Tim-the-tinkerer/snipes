import AppKit
import QuartzCore

@MainActor
final class TopDownView: NSView {
    weak var engine: GameEngine?
    private var timer: Timer?
    private var lastTime: CFTimeInterval = 0
    private var frameContext: CGContext?
    private var mixContext: CGContext?
    private var bufferSize = (0, 0)
    private var heldFrame: CGImage?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startLoop()
    }

    override func removeFromSuperview() {
        timer?.invalidate()
        timer = nil
        super.removeFromSuperview()
    }

    private func startLoop() {
        timer?.invalidate()
        lastTime = CACurrentMediaTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let engine = self.engine else { return }
                let now = CACurrentMediaTime()
                let dt = Float(min(now - self.lastTime, 0.05))
                self.lastTime = now
                if engine.phase == .playing, !engine.paused, dt > 0 {
                    engine.update(dt: dt)
                }
                self.needsDisplay = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let engine else { return }
        if engine.crtEnabled {
            drawCRT(windowCtx: ctx, engine: engine)
        } else {
            heldFrame = nil
            MazeRenderer.draw(ctx: ctx, bounds: bounds, engine: engine)
        }
        drawHUD(engine: engine)
        if engine.screenFlash > 0 {
            ctx.setFillColor(CGColor(
                red: 0.78, green: 1, blue: 0.86,
                alpha: CGFloat(engine.screenFlash) * 0.55
            ))
            ctx.fill(bounds)
        }
    }

    private func drawCRT(windowCtx: CGContext, engine: GameEngine) {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let width = max(1, Int(bounds.width * scale))
        let height = max(1, Int(bounds.height * scale))
        if bufferSize != (width, height) {
            frameContext = makeBitmap(width: width, height: height)
            mixContext = makeBitmap(width: width, height: height)
            bufferSize = (width, height)
            heldFrame = nil
        }
        guard let frameContext, let mixContext else {
            MazeRenderer.draw(ctx: windowCtx, bounds: bounds, engine: engine)
            return
        }

        let pixelBounds = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        frameContext.clear(pixelBounds)
        frameContext.saveGState()
        frameContext.scaleBy(x: scale, y: scale)
        MazeRenderer.draw(ctx: frameContext, bounds: bounds, engine: engine)
        frameContext.restoreGState()
        guard let fresh = frameContext.makeImage() else { return }

        mixContext.clear(pixelBounds)
        mixContext.setAlpha(1)
        if let heldFrame, heldFrame.width == width, heldFrame.height == height {
            mixContext.draw(heldFrame, in: pixelBounds)
            mixContext.setAlpha(0.82)
            mixContext.draw(fresh, in: pixelBounds)
            mixContext.setAlpha(1)
        } else {
            mixContext.draw(fresh, in: pixelBounds)
        }
        self.heldFrame = mixContext.makeImage()
        if let heldFrame {
            windowCtx.draw(heldFrame, in: bounds)
        }

        let layout = MazeRenderer.makeLayout(bounds: bounds)
        let map = CGRect(
            x: layout.originX,
            y: layout.originY,
            width: layout.tile * CGFloat(GameConstants.viewportW),
            height: layout.tile * CGFloat(GameConstants.viewportH)
        )
        windowCtx.saveGState()
        windowCtx.clip(to: map)
        windowCtx.setBlendMode(.plusLighter)
        windowCtx.setAlpha(0.05)
        for offset in [CGPoint(x: 1, y: 0), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: -1)] {
            windowCtx.draw(fresh, in: bounds.offsetBy(dx: offset.x, dy: offset.y))
        }
        windowCtx.restoreGState()

        windowCtx.saveGState()
        windowCtx.clip(to: map)
        windowCtx.setStrokeColor(CGColor(gray: 0, alpha: 0.2))
        windowCtx.setLineWidth(1)
        var y = map.minY + 1
        while y < map.maxY {
            windowCtx.move(to: CGPoint(x: map.minX, y: y))
            windowCtx.addLine(to: CGPoint(x: map.maxX, y: y))
            y += 3
        }
        windowCtx.strokePath()
        windowCtx.restoreGState()
    }

    private func makeBitmap(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private func drawHUD(engine: GameEngine) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.36, green: 1, blue: 0.48, alpha: 1),
        ]
        let lines = [
            "SCORE \(engine.score)   LEVEL \(engine.config.label)   \(String(repeating: "♥", count: max(0, engine.lives)))",
            "SNIPES \(engine.snipesLeft)   HIVES \(engine.hivesLeft)",
        ]
        for (i, line) in lines.enumerated() {
            (line as NSString).draw(at: CGPoint(x: 16, y: bounds.height - 22 - CGFloat(i) * 18), withAttributes: attrs)
        }
        if !engine.message.isEmpty {
            var fontSize: CGFloat = 15
            var msgAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor(calibratedRed: 1, green: 0.82, blue: 0.4, alpha: 1),
            ]
            var size = (engine.message as NSString).size(withAttributes: msgAttrs)
            while size.width > bounds.width - 24, fontSize > 11 {
                fontSize -= 1
                msgAttrs[.font] = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
                size = (engine.message as NSString).size(withAttributes: msgAttrs)
            }
            (engine.message as NSString).draw(
                at: CGPoint(x: (bounds.width - size.width) / 2, y: 12),
                withAttributes: msgAttrs
            )
        }
        if engine.phase == .playing, engine.paused {
            let p = "PAUSED"
            let pAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 28, weight: .bold),
                .foregroundColor: NSColor(calibratedRed: 1, green: 0.82, blue: 0.4, alpha: 1),
            ]
            let size = (p as NSString).size(withAttributes: pAttrs)
            (p as NSString).draw(
                at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
                withAttributes: pAttrs
            )
        }
    }
}