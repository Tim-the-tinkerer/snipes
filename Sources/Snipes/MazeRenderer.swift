import AppKit

enum MazeRenderer {
    struct Layout {
        var tile: CGFloat
        var originX: CGFloat
        var originY: CGFloat
    }

    @MainActor
    static func draw(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let maze = engine.maze
        let viewOrigin = engine.viewOrigin
        let layout = makeLayout(bounds: bounds)
        let mazeH = maze.height

        ctx.setFillColor(cgColor(0.01, 0.02, 0.015))
        ctx.fill(bounds)

        drawMaze(ctx: ctx, engine: engine, maze: maze, viewOrigin: viewOrigin, layout: layout)

        drawBolts(ctx: ctx, bolts: engine.bolts, engine: engine, viewOrigin: viewOrigin,
                  mazeH: mazeH, color: (0.35, 1.0, 0.72), layout: layout)
        drawBolts(ctx: ctx, bolts: engine.enemyBolts, engine: engine, viewOrigin: viewOrigin,
                  mazeH: mazeH, color: (1.0, 0.35, 0.45), layout: layout)

        for hive in engine.hives where hive.alive {
            guard engine.cellVisible(hive.x, hive.y) else { continue }
            drawHive(ctx: ctx, hive: hive, viewOrigin: viewOrigin, mazeH: mazeH, layout: layout)
        }
        for snipe in engine.snipes where snipe.alive {
            guard engine.cellVisible(snipe.cx, snipe.cy) else { continue }
            drawSnipe(ctx: ctx, snipe: snipe, viewOrigin: viewOrigin, mazeH: mazeH, layout: layout)
        }
        drawPlayer(
            ctx: ctx, player: engine.player, viewOrigin: viewOrigin, mazeH: mazeH, layout: layout,
            pulse: engine.playerPulse, invuln: engine.respawnInvuln
        )
        drawImpacts(ctx: ctx, engine: engine, viewOrigin: viewOrigin, layout: layout)
    }

    @MainActor
    static func makeLayout(bounds: CGRect) -> Layout {
        let hud: CGFloat = 44
        let pad: CGFloat = 12
        let usableW = bounds.width - pad * 2
        let usableH = bounds.height - hud - pad * 2
        let tile = min(
            usableW / CGFloat(GameConstants.viewportW),
            usableH / CGFloat(GameConstants.viewportH)
        )
        let mapW = tile * CGFloat(GameConstants.viewportW)
        let mapH = tile * CGFloat(GameConstants.viewportH)
        return Layout(
            tile: tile,
            originX: (bounds.width - mapW) / 2,
            originY: pad + (usableH - mapH) / 2
        )
    }

    static func cellRect(x: Int, y: Int, viewOrigin: GridPoint, layout: Layout) -> CGRect {
        let vx = x - viewOrigin.x
        let vy = y - viewOrigin.y
        return CGRect(
            x: layout.originX + CGFloat(vx) * layout.tile,
            y: layout.originY + CGFloat(GameConstants.viewportH - 1 - vy) * layout.tile,
            width: layout.tile,
            height: layout.tile
        )
    }

    @MainActor
    private static func drawMaze(
        ctx: CGContext, engine: GameEngine, maze: Maze, viewOrigin: GridPoint, layout: Layout
    ) {
        let inset = max(1, layout.tile * 0.06)
        for vy in 0..<GameConstants.viewportH {
            for vx in 0..<GameConstants.viewportW {
                let x = viewOrigin.x + vx
                let y = viewOrigin.y + vy
                let rect = cellRect(x: x, y: y, viewOrigin: viewOrigin, layout: layout)

                guard maze.inBounds(x, y) else {
                    ctx.setFillColor(cgColor(0.01, 0.02, 0.015))
                    ctx.fill(rect)
                    continue
                }

                let point = GridPoint(x: x, y: y)
                if engine.cellVisible(x, y) {
                    drawVisibleCell(ctx: ctx, maze: maze, x: x, y: y, rect: rect, inset: inset, layout: layout)
                } else if engine.explored.contains(point) {
                    drawExploredCell(ctx: ctx, maze: maze, x: x, y: y, rect: rect, inset: inset)
                } else {
                    ctx.setFillColor(cgColor(0.01, 0.02, 0.015))
                    ctx.fill(rect)
                }
            }
        }
    }

    private static func drawVisibleCell(
        ctx: CGContext, maze: Maze, x: Int, y: Int, rect: CGRect, inset: CGFloat, layout: Layout
    ) {
        let cell = maze.get(x, y)
        if cell == .wall {
            ctx.setFillColor(cgColor(0.04, 0.22, 0.10))
            ctx.fill(rect.insetBy(dx: inset * 0.3, dy: inset * 0.3))
            ctx.setStrokeColor(cgColor(0.18, 0.85, 0.38, 0.55))
            ctx.setLineWidth(max(1, layout.tile * 0.05))
            ctx.stroke(rect.insetBy(dx: inset * 0.5, dy: inset * 0.5))
        } else {
            let alt = (x + y) % 2 == 0
            ctx.setFillColor(cgColor(0.03, alt ? 0.11 : 0.14, alt ? 0.06 : 0.08))
            ctx.fill(rect.insetBy(dx: inset, dy: inset))
            if cell == .hive {
                ctx.setFillColor(cgColor(0.12, 0.03, 0.05))
                ctx.fillEllipse(in: rect.insetBy(dx: layout.tile * 0.2, dy: layout.tile * 0.2))
            }
        }
    }

    private static func drawExploredCell(
        ctx: CGContext, maze: Maze, x: Int, y: Int, rect: CGRect, inset: CGFloat
    ) {
        if maze.isWall(x, y) {
            ctx.setFillColor(cgColor(0.025, 0.06, 0.035))
            ctx.fill(rect.insetBy(dx: inset * 0.4, dy: inset * 0.4))
        } else {
            ctx.setFillColor(cgColor(0.02, 0.05, 0.03))
            ctx.fill(rect.insetBy(dx: inset, dy: inset))
        }
    }

    private static func drawHive(
        ctx: CGContext, hive: Hive, viewOrigin: GridPoint, mazeH: Int, layout: Layout
    ) {
        let rect = cellRect(x: hive.x, y: hive.y, viewOrigin: viewOrigin, layout: layout)
        let pop: CGFloat = hive.flash > 0 ? 0.08 : 0
        let r = rect.insetBy(dx: layout.tile * (0.14 - pop), dy: layout.tile * (0.14 - pop))
        if hive.flash > 0 {
            ctx.setFillColor(cgColor(1.0, 0.94, 0.86))
            ctx.setStrokeColor(cgColor(1, 1, 1))
        } else {
            ctx.setFillColor(cgColor(0.55, 0.05, 0.12))
            ctx.setStrokeColor(cgColor(1.0, 0.25, 0.35))
        }
        ctx.fillEllipse(in: r)
        ctx.setLineWidth(max(1.5, layout.tile * 0.08))
        ctx.strokeEllipse(in: r)
        if hive.hp > 1 {
            let dot = layout.tile * 0.1
            for i in 0..<min(hive.hp, 4) {
                ctx.setFillColor(cgColor(1.0, 0.6, 0.65))
                ctx.fillEllipse(in: CGRect(
                    x: r.minX + CGFloat(i) * dot * 1.4,
                    y: r.maxY - dot,
                    width: dot,
                    height: dot
                ))
            }
        }
    }

    private static func drawSnipe(
        ctx: CGContext, snipe: Snipe, viewOrigin: GridPoint, mazeH: Int, layout: Layout
    ) {
        let rect = cellRect(x: snipe.cx, y: snipe.cy, viewOrigin: viewOrigin, layout: layout)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let pop: CGFloat = snipe.pulse > 0 ? CGFloat(snipe.pulse / 0.04) : 0
        let r = layout.tile * (0.28 + 0.1 * pop)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x, y: center.y + r))
        path.addLine(to: CGPoint(x: center.x + r, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y - r))
        path.addLine(to: CGPoint(x: center.x - r, y: center.y))
        path.closeSubpath()
        ctx.setFillColor(cgColor(1.0, 0.62, 0.05))
        ctx.addPath(path)
        ctx.fillPath()
        ctx.setStrokeColor(cgColor(1.0, 0.85, 0.35))
        ctx.setLineWidth(max(1, layout.tile * 0.06))
        ctx.addPath(path)
        ctx.strokePath()
    }

    private static func drawPlayer(
        ctx: CGContext, player: PlayerState, viewOrigin: GridPoint, mazeH: Int, layout: Layout,
        pulse: Float, invuln: Float
    ) {
        let rect = cellRect(x: player.cx, y: player.cy, viewOrigin: viewOrigin, layout: layout)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let pop: CGFloat = pulse > 0 ? CGFloat(pulse / 0.04) : 0
        let body = layout.tile * (0.3 + 0.12 * pop)
        let blink = invuln > 0 && Int(invuln * 10) % 2 == 0
        ctx.setFillColor(cgColor(0.28, 1.0, 0.48, blink ? 0.35 : 1))
        ctx.fillEllipse(in: CGRect(x: center.x - body, y: center.y - body, width: body * 2, height: body * 2))

        let tip = CGPoint(
            x: center.x + CGFloat(GameConstants.dir8[player.facing].0) * body * 1.35,
            y: center.y - CGFloat(GameConstants.dir8[player.facing].1) * body * 1.35
        )
        ctx.setStrokeColor(cgColor(0.55, 1.0, 0.72))
        ctx.setLineWidth(max(2, layout.tile * 0.1))
        ctx.move(to: center)
        ctx.addLine(to: tip)
        ctx.strokePath()
    }

    @MainActor
    private static func drawBolts(
        ctx: CGContext, bolts: [Bolt], engine: GameEngine, viewOrigin: GridPoint,
        mazeH: Int, color: (CGFloat, CGFloat, CGFloat), layout: Layout
    ) {
        let r = max(2, layout.tile * 0.12)
        for bolt in bolts {
            let cell = engine.maze.worldToCell(wx: bolt.x, wz: bolt.z)
            guard engine.cellVisible(cell.x, cell.y) else { continue }
            let point = worldToDrawPoint(bolt.x, bolt.z, viewOrigin: viewOrigin, layout: layout)
            ctx.setFillColor(cgColor(color.0, color.1, color.2))
            ctx.fillEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
        }
    }

    @MainActor
    private static func drawImpacts(
        ctx: CGContext, engine: GameEngine, viewOrigin: GridPoint, layout: Layout
    ) {
        for impact in engine.impacts {
            let cell = engine.maze.worldToCell(wx: impact.x, wz: impact.z)
            guard engine.cellVisible(cell.x, cell.y) else { continue }
            let point = worldToDrawPoint(impact.x, impact.z, viewOrigin: viewOrigin, layout: layout)
            let t = CGFloat(max(0, impact.life / impact.maxLife))
            switch impact.kind {
            case .hit:
                let r = layout.tile * 0.34
                let path = CGMutablePath()
                path.move(to: CGPoint(x: point.x, y: point.y + r))
                path.addLine(to: CGPoint(x: point.x + r, y: point.y))
                path.addLine(to: CGPoint(x: point.x, y: point.y - r))
                path.addLine(to: CGPoint(x: point.x - r, y: point.y))
                path.closeSubpath()
                ctx.setFillColor(cgColor(0.92, 1, 0.86, t))
                ctx.addPath(path)
                ctx.fillPath()
            case .hiveDestroy:
                let radius = layout.tile * (0.25 + 1.35 * (1 - t))
                ctx.setStrokeColor(cgColor(1, 0.45, 0.55, t))
                ctx.setLineWidth(max(2, layout.tile * 0.07))
                ctx.strokeEllipse(in: CGRect(
                    x: point.x - radius, y: point.y - radius,
                    width: radius * 2, height: radius * 2
                ))
            case .muzzle:
                let r = layout.tile * 0.14
                ctx.setFillColor(cgColor(0.85, 1, 0.75, t))
                ctx.fillEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
            }
        }
    }

    private static func worldToDrawPoint(_ wx: Float, _ wz: Float, viewOrigin: GridPoint, layout: Layout) -> CGPoint {
        let gx = wx / GameConstants.cellSize + Float(GameConstants.mazeW) / 2
        let gy = wz / GameConstants.cellSize + Float(GameConstants.mazeH) / 2
        let rect = cellRect(x: Int(gx), y: Int(gy), viewOrigin: viewOrigin, layout: layout)
        let fx = CGFloat(gx - floor(gx))
        let fy = CGFloat(gy - floor(gy))
        return CGPoint(
            x: rect.minX + fx * layout.tile,
            y: rect.minY + (1 - fy) * layout.tile
        )
    }

    private static func cgColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }
}