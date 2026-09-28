import AVFoundation

enum GameSound {
    case bullet
    case spear
    case explodeSnipe
    case explodeHive
    case explodePlayer
    case hiveHit
    case levelClear
    case gameOver
    case levelStart
    case snipeSpawn
}

enum MusicMode: Int, CaseIterable {
    case off = 0
    case low = 1
    case full = 2

    var label: String {
        switch self {
        case .off: return "OFF"
        case .low: return "LOW"
        case .full: return "FULL"
        }
    }

    var gain: Float {
        switch self {
        case .off: return 0
        case .low: return 0.34
        case .full: return 0.62
        }
    }
}

@MainActor
final class AudioManager {
    static let shared = AudioManager()

    private let engine = AVAudioEngine()
    private let mixer: AVAudioMixerNode
    private let players: [AVAudioPlayerNode]
    private let musicPlayer = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var nextPlayer = 0
    private var cache: [GameSound: AVAudioPCMBuffer] = [:]
    private var variants: [GameSound: [AVAudioPCMBuffer]] = [:]
    private var lastPlayed: [GameSound: TimeInterval] = [:]

    private var musicQueueTimer: Timer?
    private var queuedMusicSegments = 0
    private var musicGeneration = 0
    private var musicActive = false
    private var musicPaused = false
    private var musicIntensity: Float = 0
    private var musicDanger: Float = 0
    private var musicDronePhaseA: Float = 0
    private var musicDronePhaseB: Float = 0
    private var musicLFOPhase: Float = 0
    private var musicGhostPhase: Float = 0
    private var musicHeartbeatClock: Float = 0
    private var musicNoiseState: UInt32 = 0x51A7_2026
    private var musicNoiseLowpass: Float = 0
    private(set) var musicMode: MusicMode = .full

    /// Stops identical fire and spawn sounds from stacking into a buzz.
    private let minGap: [GameSound: TimeInterval] = [
        .bullet: 0.05,
        .spear: 0.075,
        .hiveHit: 0.06,
        .snipeSpawn: 0.10,
    ]

    var enabled = true {
        didSet {
            mixer.outputVolume = enabled ? volume : 0
            serviceMusicQueue()
        }
    }

    var volume: Float = 0.55 {
        didSet { mixer.outputVolume = enabled ? volume : 0 }
    }

    private init() {
        let sampleRate = 44_100.0
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        mixer = engine.mainMixerNode
        players = (0..<8).map { _ in AVAudioPlayerNode() }

        for player in players {
            engine.attach(player)
            engine.connect(player, to: mixer, format: format)
        }

        engine.attach(musicPlayer)
        engine.connect(musicPlayer, to: mixer, format: format)

        if let raw = UserDefaults.standard.object(forKey: "snipes.musicMode") as? Int,
           let stored = MusicMode(rawValue: raw) {
            musicMode = stored
        }
        musicPlayer.volume = musicMode.gain
        mixer.outputVolume = volume

        preloadSounds()
        try? engine.start()

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.serviceMusicQueue()
            }
        }
        musicQueueTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func toggleEnabled() {
        enabled.toggle()
    }

    func cycleMusicMode() {
        let modes = MusicMode.allCases
        guard let index = modes.firstIndex(of: musicMode) else { return }
        musicMode = modes[(index + 1) % modes.count]
        UserDefaults.standard.set(musicMode.rawValue, forKey: "snipes.musicMode")
        musicPlayer.volume = musicMode.gain
        restartMusicQueue()
    }

    func setMusicState(active: Bool, paused: Bool, intensity: Float, danger: Float) {
        let wasActive = musicActive
        let wasPaused = musicPaused
        musicActive = active
        musicPaused = paused
        musicIntensity = min(1, max(0, intensity))
        musicDanger = min(1, max(0, danger))

        if wasActive != active || wasPaused != paused {
            serviceMusicQueue()
        }
    }

    private func restartMusicQueue() {
        musicGeneration &+= 1
        queuedMusicSegments = 0
        musicPlayer.stop()
        serviceMusicQueue()
    }

    private func serviceMusicQueue() {
        guard enabled, musicMode != .off, musicActive else {
            if musicPlayer.isPlaying || queuedMusicSegments > 0 {
                musicGeneration &+= 1
                queuedMusicSegments = 0
                musicPlayer.stop()
            }
            return
        }

        if musicPaused {
            if musicPlayer.isPlaying { musicPlayer.pause() }
            return
        }

        if !engine.isRunning {
            try? engine.start()
        }

        while queuedMusicSegments < 2 {
            queueAmbientSegment()
        }

        if !musicPlayer.isPlaying {
            musicPlayer.play()
        }
    }

    private func queueAmbientSegment() {
        let generation = musicGeneration
        let buffer = makeAmbientSegment(
            intensity: musicIntensity,
            danger: musicDanger,
            mode: musicMode
        )
        queuedMusicSegments += 1
        musicPlayer.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            Task { @MainActor in
                guard let self, self.musicGeneration == generation else { return }
                self.queuedMusicSegments = max(0, self.queuedMusicSegments - 1)
                self.serviceMusicQueue()
            }
        }
    }

    private func makeAmbientSegment(
        intensity: Float,
        danger: Float,
        mode: MusicMode
    ) -> AVAudioPCMBuffer {
        let sampleRate = Float(format.sampleRate)
        let duration: Float = 3.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        // A fixed low tonal center keeps this feeling like atmosphere instead of a melody.
        // The slightly detuned pair produces a slow beating drone.
        let root: Float = 55
        let freqA = root * (0.995 + intensity * 0.004)
        let freqB = root * 1.498
        let tritone = root * 2.828
        let full = mode == .full

        let eventCount = full ? (1 + Int((intensity * 3).rounded(.down))) : 1
        let eventFreqs: [Float] = [
            tritone,
            root * 3.0,
            root * 3.178,
            root * 4.238,
        ]
        let events: [(start: Float, freq: Float, decay: Float)] = (0..<eventCount).map { _ in
            (
                start: Float.random(in: 0.3...(duration - 1.35)),
                freq: eventFreqs.randomElement() ?? tritone,
                decay: Float.random(in: 1.7...3.2)
            )
        }

        let heartbeatInterval = max(0.62, 1.42 - danger * 0.72)
        let droneLevel: Float = mode == .low ? 0.11 : 0.14 + intensity * 0.035
        let dissonanceLevel: Float = full ? (0.012 + intensity * 0.028) : 0.007

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate

            musicDronePhaseA += 2 * .pi * freqA / sampleRate
            musicDronePhaseB += 2 * .pi * freqB / sampleRate
            musicLFOPhase += 2 * .pi * (0.045 + intensity * 0.018) / sampleRate
            musicGhostPhase += 2 * .pi * tritone / sampleRate
            musicHeartbeatClock += 1 / sampleRate
            if musicDronePhaseA > 2 * .pi { musicDronePhaseA -= 2 * .pi }
            if musicDronePhaseB > 2 * .pi { musicDronePhaseB -= 2 * .pi }
            if musicLFOPhase > 2 * .pi { musicLFOPhase -= 2 * .pi }
            if musicGhostPhase > 2 * .pi { musicGhostPhase -= 2 * .pi }
            if musicHeartbeatClock >= heartbeatInterval {
                musicHeartbeatClock = fmodf(musicHeartbeatClock, heartbeatInterval)
            }

            let lfo = 0.72 + 0.28 * sinf(musicLFOPhase)
            var sample = (
                sinf(musicDronePhaseA) * 0.72 +
                sinf(musicDronePhaseB) * 0.28
            ) * droneLevel * lfo

            // Filtered noise gives the maze a faint electrical/air-system texture.
            musicNoiseState = musicNoiseState &* 1_664_525 &+ 1_013_904_223
            let white = Float(musicNoiseState & 0xFFFF) / 32_767.5 - 1
            let smoothing: Float = 0.0022 + intensity * 0.0015
            musicNoiseLowpass += (white - musicNoiseLowpass) * smoothing
            sample += musicNoiseLowpass * (mode == .low ? 0.018 : 0.026)

            // Sparse high clusters: metallic, short and deliberately non-melodic.
            for event in events {
                let local = t - event.start
                if local >= 0, local < 1.3 {
                    let attack = min(1, local / 0.025)
                    let env = attack * expf(-event.decay * local)
                    let wobble = sinf(2 * .pi * 0.7 * local) * 2.2
                    let tone = sinf(2 * .pi * (event.freq + wobble) * local)
                    let overtone = sinf(2 * .pi * event.freq * 1.503 * local)
                    sample += (tone * 0.72 + overtone * 0.28) * env * dissonanceLevel
                }
            }

            // At higher danger, add a low double pulse rather than a musical beat.
            if full, danger > 0.38 {
                let cycle = musicHeartbeatClock
                for offset: Float in [0, 0.15] {
                    let local = cycle - offset
                    if local >= 0, local < 0.26 {
                        let env = expf(-12 * local)
                        let thump = sinf(2 * .pi * (48 + danger * 12) * local)
                        sample += thump * env * (0.014 + danger * 0.035)
                    }
                }
            }

            // A quiet tritone ghost appears as the maze becomes more hostile.
            if full {
                let ghost = sinf(musicGhostPhase + sinf(musicLFOPhase) * 0.8)
                sample += ghost * (0.002 + danger * 0.008)
            }

            samples[i] = max(-0.7, min(0.7, sample))
        }

        return buffer
    }

    func play(_ sound: GameSound) {
        guard enabled else { return }
        let now = Date().timeIntervalSinceReferenceDate
        if let gap = minGap[sound], let last = lastPlayed[sound], now - last < gap {
            return
        }
        guard let buffer = variants[sound]?.randomElement() ?? cache[sound] else { return }
        lastPlayed[sound] = now
        let player = players[nextPlayer % players.count]
        nextPlayer += 1
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    private func preloadSounds() {
        remember(.bullet, makeBullet(), varyPitch: true)
        remember(.spear, makeSpear(), varyPitch: true)
        remember(.explodeSnipe, makeExplosion(base: 260, duration: 0.18, fall: 520, volume: 0.28), varyPitch: true)
        remember(.explodeHive, makeHiveDestroy(), varyPitch: true)
        remember(.explodePlayer, makePlayerDeath(), varyPitch: true)
        remember(.hiveHit, makeThud(frequency: 180, duration: 0.12), varyPitch: true)
        remember(.levelClear, makeFanfare(), varyPitch: false)
        remember(.gameOver, makeGameOver(), varyPitch: false)
        remember(.levelStart, makeLevelStart(), varyPitch: false)
        remember(.snipeSpawn, makeTone(
            frequency: 220, duration: 0.07, volume: 0.09,
            attack: 0.004, decay: 14, slide: -80
        ), varyPitch: true)
    }

    private func remember(_ sound: GameSound, _ buffer: AVAudioPCMBuffer, varyPitch: Bool) {
        if varyPitch {
            variants[sound] = [0.94, 1.0, 1.06].map { pitched(buffer, by: $0) }
        } else {
            cache[sound] = buffer
        }
    }

    private func pitched(_ buffer: AVAudioPCMBuffer, by ratio: Float) -> AVAudioPCMBuffer {
        if abs(ratio - 1) < 0.001 { return buffer }
        let srcCount = Int(buffer.frameLength)
        guard srcCount > 1 else { return buffer }
        let dstCount = max(1, Int(Float(srcCount) / ratio))
        let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(dstCount))!
        out.frameLength = AVAudioFrameCount(dstCount)
        let src = buffer.floatChannelData![0]
        let dst = out.floatChannelData![0]
        let last = srcCount - 1
        for i in 0..<dstCount {
            let pos = min(Float(last), Float(i) * ratio)
            let i0 = min(last, Int(pos))
            let i1 = min(last, i0 + 1)
            let fraction = pos - Float(i0)
            dst[i] = src[i0] * (1 - fraction) + src[i1] * fraction
        }
        return out
    }

    private func makeBullet() -> AVAudioPCMBuffer {
        makeTone(frequency: 920, duration: 0.07, volume: 0.16, attack: 0.001, decay: 28, slide: -640)
    }

    private func makeSpear() -> AVAudioPCMBuffer {
        makeTone(frequency: 340, duration: 0.11, volume: 0.12, attack: 0.002, decay: 16, slide: -160)
    }

    private func makeThud(frequency: Float, duration: Float) -> AVAudioPCMBuffer {
        makeTone(frequency: frequency, duration: duration, volume: 0.2, attack: 0.001, decay: 22, slide: -60)
    }

    /// Low double pulse. Tonal, so a hive kill does not sound like a Snipe crackle.
    private func makeHiveDestroy() -> AVAudioPCMBuffer {
        let sampleRate = Float(format.sampleRate)
        let duration: Float = 0.46
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        let notes: [(start: Float, freq: Float)] = [(0, 164), (0.16, 98)]
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            var sample: Float = 0
            for note in notes {
                let local = t - note.start
                guard local >= 0 else { continue }
                let env = exp(-7 * local)
                let tone = sinf(2 * .pi * note.freq * local)
                let body = sinf(2 * .pi * note.freq * 0.5 * local)
                sample += (tone * 0.7 + body * 0.3) * env
            }
            samples[i] = sample * 0.32
        }
        return buffer
    }

    /// Longer and lower than a Snipe explosion, with a sharp opening crack.
    private func makePlayerDeath() -> AVAudioPCMBuffer {
        let sampleRate = Float(format.sampleRate)
        let duration: Float = 0.55
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        var noiseState: UInt32 = 90_210
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let env = exp(-5 * t) * (1 - t / duration)
            let crack = t < 0.02 ? (1 - t / 0.02) : 0
            noiseState = noiseState &* 1_103_515_245 &+ 12_345
            let noise = Float(noiseState % 10_000) / 10_000 - 0.5
            let thump = sinf(2 * .pi * (78 - 90 * t) * t)
            samples[i] = (thump * 0.75 + noise * (0.45 + crack)) * env * 0.5
        }
        return buffer
    }

    private func makeExplosion(base: Float, duration: Float, fall: Float, volume: Float) -> AVAudioPCMBuffer {
        let sampleRate = Float(format.sampleRate)
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        var noiseState: UInt32 = 12_345

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let env = exp(-7 * t) * (1 - t / duration)
            let freq = base - fall * t
            noiseState = noiseState &* 1_103_515_245 &+ 12_345
            let noise = Float(noiseState % 10_000) / 10_000
            let tone = sinf(2 * .pi * freq * t)
            let crackle = (noise - 0.5) * 0.55
            samples[i] = (tone * 0.55 + crackle) * env * volume
        }
        return buffer
    }

    private func makeFanfare() -> AVAudioPCMBuffer {
        let notes: [Float] = [392, 494, 587, 784]
        let sampleRate = Float(format.sampleRate)
        let noteLen: Float = 0.1
        let frameCount = AVAudioFrameCount(noteLen * Float(notes.count) * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for (n, freq) in notes.enumerated() {
            let start = Int(Float(n) * noteLen * sampleRate)
            let end = min(Int(frameCount), start + Int(noteLen * sampleRate))
            for i in start..<end {
                let t = Float(i - start) / sampleRate
                let env = exp(-10 * t)
                samples[i] = sinf(2 * .pi * freq * t) * env * 0.24
            }
        }
        return buffer
    }

    private func makeGameOver() -> AVAudioPCMBuffer {
        let notes: [Float] = [220, 185, 147, 110]
        let sampleRate = Float(format.sampleRate)
        let noteLen: Float = 0.18
        let frameCount = AVAudioFrameCount(noteLen * Float(notes.count) * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for (n, freq) in notes.enumerated() {
            let start = Int(Float(n) * noteLen * sampleRate)
            let end = min(Int(frameCount), start + Int(noteLen * sampleRate))
            for i in start..<end {
                let t = Float(i - start) / sampleRate
                let env = exp(-4 * t)
                samples[i] = sinf(2 * .pi * freq * t) * env * 0.26
            }
        }
        return buffer
    }

    private func makeLevelStart() -> AVAudioPCMBuffer {
        let sampleRate = Float(format.sampleRate)
        let noteLen: Float = 0.08
        let frameCount = AVAudioFrameCount(noteLen * 2 * sampleRate + sampleRate * 0.04)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        let freqs: [Float] = [440, 554]
        for (n, freq) in freqs.enumerated() {
            let start = Int(Float(n) * (noteLen + 0.04) * sampleRate)
            let end = min(Int(frameCount), start + Int(noteLen * sampleRate))
            for i in start..<end {
                let t = Float(i - start) / sampleRate
                let env = exp(-14 * t)
                samples[i] = sinf(2 * .pi * freq * t) * env * 0.2
            }
        }
        return buffer
    }

    private func makeTone(
        frequency: Float,
        duration: Float,
        volume: Float,
        attack: Float,
        decay: Float,
        slide: Float = 0
    ) -> AVAudioPCMBuffer {
        let sampleRate = Float(format.sampleRate)
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let attackEnv = min(1, t / attack)
            let decayEnv = exp(-decay * t)
            let freq = frequency + slide * t
            samples[i] = sinf(2 * .pi * freq * t) * volume * attackEnv * decayEnv
        }
        return buffer
    }
}