import Foundation

enum RetroArcadeSynth {
    static func makeDiscoveryWAV() -> Data {
        let sampleRate = 22_050
        let notes: [Double] = [659.25, 830.61, 987.77, 1_318.51, 987.77, 1_318.51]
        let noteDuration = 0.075
        let gateDuration = 0.065
        let tailDuration = 0.08
        let totalDuration = (Double(notes.count) * noteDuration) + tailDuration
        let totalSamples = Int(totalDuration * Double(sampleRate))
        var samples = [Float](repeating: 0, count: totalSamples)

        for (index, frequency) in notes.enumerated() {
            let noteStart = Double(index) * noteDuration
            let noteEnd = noteStart + gateDuration
            let startSample = Int(noteStart * Double(sampleRate))
            let endSample = min(totalSamples, Int(noteEnd * Double(sampleRate)))
            let detune = frequency * 0.008

            for sampleIndex in startSample..<endSample {
                let t = Double(sampleIndex) / Double(sampleRate)
                let localTime = t - noteStart
                let phase = (localTime * frequency).truncatingRemainder(dividingBy: 1)
                let phaseDetuned = (localTime * (frequency + detune)).truncatingRemainder(dividingBy: 1)
                let sqA: Float = phase < 0.5 ? 0.92 : -0.92
                let sqB: Float = phaseDetuned < 0.5 ? 0.78 : -0.78
                let attack = min(1, localTime / 0.006)
                let release = min(1, max(0, noteEnd - t) / 0.012)
                let envelope = Float(attack * release)
                let tone = (sqA * 0.62 + sqB * 0.38) * envelope
                samples[sampleIndex] += tone
            }
        }

        let normalized = normalizeAndBitCrush(samples, bits: 5, drive: 0.86)
        return makeWAV(from: normalized, sampleRate: sampleRate)
    }

    static func makeExplosionWAV() -> Data {
        let sampleRate = 22_050
        let duration = 0.72
        let totalSamples = Int(duration * Double(sampleRate))
        var samples = [Float](repeating: 0, count: totalSamples)

        var lcgState: UInt64 = 0xF00D_BA11
        func nextNoise() -> Float {
            lcgState = lcgState &* 6364136223846793005 &+ 1
            let value = Float((lcgState >> 32) & 0xFFFF) / Float(0xFFFF)
            return (value * 2) - 1
        }

        for i in 0..<totalSamples {
            let t = Double(i) / Double(sampleRate)
            let progress = min(1, t / duration)
            let pitchDrop = 170 - (145 * progress)
            let squarePhase = (t * pitchDrop).truncatingRemainder(dividingBy: 1)
            let square: Float = squarePhase < 0.48 ? 1 : -1
            let noise = nextNoise()
            let transient = exp(-t * 19)
            let body = exp(-t * 4.8)
            let rumble = Float(sin(2 * .pi * 52 * t)) * Float(exp(-t * 3.1))

            var output = (square * Float(body) * 0.34)
            output += noise * Float(transient) * 0.82
            output += rumble * 0.36
            output += noise * Float(body) * 0.18

            if t < 0.045 {
                output += (noise * 0.5) * Float((0.045 - t) / 0.045)
            }

            samples[i] = output
        }

        let normalized = normalizeAndBitCrush(samples, bits: 4, drive: 0.92)
        return makeWAV(from: normalized, sampleRate: sampleRate)
    }

    static func makeVictoryWAV() -> Data {
        let sampleRate = 22_050
        let notes: [Double] = [
            523.25, 659.25, 783.99,
            659.25, 783.99, 1_046.50,
            783.99, 1_046.50, 1_318.51
        ]
        let noteDuration = 0.085
        let gateDuration = 0.075
        let totalDuration = (Double(notes.count) * noteDuration) + 0.14
        let totalSamples = Int(totalDuration * Double(sampleRate))
        var samples = [Float](repeating: 0, count: totalSamples)

        for (index, frequency) in notes.enumerated() {
            let noteStart = Double(index) * noteDuration
            let noteEnd = noteStart + gateDuration
            let startSample = Int(noteStart * Double(sampleRate))
            let endSample = min(totalSamples, Int(noteEnd * Double(sampleRate)))

            for sampleIndex in startSample..<endSample {
                let t = Double(sampleIndex) / Double(sampleRate)
                let localTime = t - noteStart
                let phase = (localTime * frequency).truncatingRemainder(dividingBy: 1)
                let phaseOctave = (localTime * (frequency * 2)).truncatingRemainder(dividingBy: 1)
                let squareMain: Float = phase < 0.5 ? 0.88 : -0.88
                let squareOct: Float = phaseOctave < 0.5 ? 0.68 : -0.68
                let attack = min(1, localTime / 0.005)
                let release = min(1, max(0, noteEnd - t) / 0.018)
                let envelope = Float(attack * release)
                let tone = ((squareMain * 0.7) + (squareOct * 0.3)) * envelope
                samples[sampleIndex] += tone
            }
        }

        let normalized = normalizeAndBitCrush(samples, bits: 5, drive: 0.88)
        return makeWAV(from: normalized, sampleRate: sampleRate)
    }

    static func makeCountdownBeepWAV() -> Data {
        let sampleRate = 22_050
        let duration = 0.11
        let totalSamples = Int(duration * Double(sampleRate))
        var samples = [Float](repeating: 0, count: totalSamples)
        let frequency = 1_560.0
        let detune = 7.0

        for i in 0..<totalSamples {
            let t = Double(i) / Double(sampleRate)
            let phase = (t * frequency).truncatingRemainder(dividingBy: 1)
            let phaseDetuned = (t * (frequency + detune)).truncatingRemainder(dividingBy: 1)
            let squareA: Float = phase < 0.5 ? 1 : -1
            let squareB: Float = phaseDetuned < 0.5 ? 0.86 : -0.86
            let attack = min(1, t / 0.004)
            let release = min(1, max(0, duration - t) / 0.03)
            let envelope = Float(attack * release)
            samples[i] = (squareA * 0.58 + squareB * 0.42) * envelope
        }

        let normalized = normalizeAndBitCrush(samples, bits: 5, drive: 0.74)
        return makeWAV(from: normalized, sampleRate: sampleRate)
    }

    private static func normalizeAndBitCrush(_ samples: [Float], bits: Int, drive: Float) -> [Float] {
        let peak = max(samples.map { abs($0) }.max() ?? 1, 0.001)
        let scale = drive / peak
        let steps = Float((1 << bits) - 1)

        return samples.map { sample in
            let amplified = tanh(sample * scale * 1.2)
            let quantized = round(((amplified * 0.5) + 0.5) * steps) / steps
            return (quantized * 2) - 1
        }
    }

    private static func makeWAV(from samples: [Float], sampleRate: Int) -> Data {
        let channelCount = 1
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let dataSize = samples.count * bytesPerSample
        let byteRate = sampleRate * channelCount * bytesPerSample
        let blockAlign = channelCount * bytesPerSample
        let riffSize = 36 + dataSize

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendUInt32LE(UInt32(riffSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendUInt32LE(16)
        data.appendUInt16LE(1)
        data.appendUInt16LE(UInt16(channelCount))
        data.appendUInt32LE(UInt32(sampleRate))
        data.appendUInt32LE(UInt32(byteRate))
        data.appendUInt16LE(UInt16(blockAlign))
        data.appendUInt16LE(UInt16(bitsPerSample))
        data.append(contentsOf: Array("data".utf8))
        data.appendUInt32LE(UInt32(dataSize))

        for sample in samples {
            let clipped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clipped * Float(Int16.max))
            data.appendUInt16LE(UInt16(bitPattern: int16))
        }

        return data
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { buffer in
            append(contentsOf: buffer)
        }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { buffer in
            append(contentsOf: buffer)
        }
    }
}
