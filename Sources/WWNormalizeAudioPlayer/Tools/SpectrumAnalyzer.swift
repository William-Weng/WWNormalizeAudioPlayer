//
//  SpectrumAnalyzer.swift
//  WWNormalizeAudioPlayer
//
//  Created by William on 2026/6/2.
//

import AVFAudio
import Accelerate

/// 即時頻譜分析器
/// - Note: 使用 AVAudioEngine 的 tap 取得即時 PCM buffer，並透過 FFT 產生 32 段頻譜 bar data。
extension WWNormalizeAudioPlayer {
    
    public final class SpectrumAnalyzer {
        
        private let queue = DispatchQueue(label: "io.github.william-weng.WWNormalizeAudioPlayer")        /// 背景分析 queue

        private let fftSize: Int
        private let barCount: Int
        private let log2n: vDSP_Length
        private let fftSetup: FFTSetup
        
        private var minDB: Float = -80                  // 振幅正規化的最低 dB 值
        private var maxDB: Float = 0                    // 振幅正規化的最高 dB 值
        private var smoothing: Float = 0.25             // bar 平滑係數，越大反應越快，越小越平滑
        private var smoothedBars: [Float]               // 平滑用的暫存 bar 值
        
        /// 建立頻譜分析器
        /// - Parameters:
        ///   - fftSize: FFT 大小，必須是 2 的次方
        ///   - barCount: 頻譜 bar 數量
        public init(fftSize: Int = 1024, barCount: Int = 32) {
            
            precondition(fftSize > 0 && (fftSize & (fftSize - 1)) == 0, "fftSize must be power of 2")
            precondition(barCount > 0, "barCount must be greater than 0")
            
            self.fftSize = fftSize
            self.barCount = barCount
            self.log2n = vDSP_Length(log2(Float(fftSize)))
            self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
            self.smoothedBars = Array(repeating: 0, count: barCount)
        }
        
        deinit {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
}

// MARK: - WWNormalizeAudioPlayer.SpectrumAnalyzer
public extension WWNormalizeAudioPlayer.SpectrumAnalyzer {
    
    /// 在指定節點上安裝 tap，開始即時分析頻譜
    /// - Parameters:
    ///   - node: 要監聽的音訊節點
    ///   - bus: 監聽的 bus，預設為 0
    ///   - sampleRate: 音訊取樣率
    ///   - minFrequency: 最低分析頻率，預設為 20 Hz
    ///   - maxFrequency: 最高分析頻率，預設為 Nyquist frequency
    ///   - handler: 分析完成後回傳 32 段 bar data
    func installTap(on node: AVAudioNode, bus: AVAudioNodeBus = 0, sampleRate: Double, minFrequency: Float = 20, maxFrequency: Float? = nil, handler: @escaping WWNormalizeAudioPlayer.SpectrumBarsHandler) {
        
        let format = node.outputFormat(forBus: bus)
        let upper = maxFrequency ?? Float(sampleRate / 2.0)
        
        node.installTap(onBus: bus, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            
            guard let self else { return }
            
            self.queue.async {
                let bars = self.analyze(buffer: buffer, sampleRate: sampleRate, minFrequency: minFrequency, maxFrequency: upper)
                handler(bars)
            }
        }
    }
    
    /// 移除 tap
    /// - Parameters:
    ///   - node: 要移除 tap 的節點
    ///   - bus: bus，預設為 0
    func removeTap(from node: AVAudioNode, bus: AVAudioNodeBus = 0) {
        node.removeTap(onBus: bus)
    }
    
    /// 重置所有平滑狀態與參數
    func reset() {
        
        queue.sync {
            smoothedBars = Array(repeating: 0, count: barCount)
            minDB = -80
            maxDB = 0
            smoothing = 0.25
        }
    }
    
    /// 更新平滑係數
    /// - Parameter smoothing: 平滑係數，建議範圍 0...1
    func updateSmoothing(_ smoothing: Float) {
        
        queue.sync {
            self.smoothing = min(max(smoothing, 0), 1)
        }
    }
    
    /// 更新 dB 正規化範圍
    /// - Parameters:
    ///   - min: 最低 dB
    ///   - max: 最高 dB
    func updateDBRange(min: Float, max: Float) {
        
        queue.sync {
            guard max > min else { return }
            self.minDB = min
            self.maxDB = max
        }
    }
}

private extension WWNormalizeAudioPlayer.SpectrumAnalyzer {
    
    /// 分析單一 PCM buffer，轉成 32 段 bar data
    /// - Parameters:
    ///   - buffer: 即時音訊 buffer
    ///   - sampleRate: 取樣率
    ///   - minFrequency: 最低分析頻率
    ///   - maxFrequency: 最高分析頻率
    /// - Returns: 正規化後的 bar data
    func analyze(buffer: AVAudioPCMBuffer, sampleRate: Double, minFrequency: Float, maxFrequency: Float) -> [WWNormalizeAudioPlayer.SpectrumBar] {
        
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        
        let frameLength = Int(buffer.frameLength)
        
        guard frameLength >= fftSize else { return [] }
        
        let startIndex = frameLength - fftSize
        let samples = Array(UnsafeBufferPointer(start: channelData.advanced(by: startIndex), count: fftSize))
        
        let windowed = applyHannWindow(samples)
        let spectrum = performFFT(samples: windowed)
        let bands = splitIntoBars(spectrum: spectrum, sampleRate: sampleRate, minFrequency: minFrequency, maxFrequency: maxFrequency)
        
        return bands.enumerated().map { index, band in
            
            let normalized = normalizeDB(band.amplitude)
            let smoothed = smooth(value: normalized, index: index)
            
            return .init(index: index, lowerFrequency: band.lowerFrequency, upperFrequency: band.upperFrequency, amplitude: smoothed)
        }
    }
    
    /// 套用 Hann window，降低 FFT leakage
    /// - Parameter samples: 原始取樣資料
    /// - Returns: 套用 window 後的資料
    func applyHannWindow(_ samples: [Float]) -> [Float] {
        
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        var result = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &result, 1, vDSP_Length(fftSize))
        return result
    }
    
    /// 執行 FFT 並轉成 dB 頻譜
    /// - Parameter samples: 已套用 window 的音訊資料
    /// - Returns: 每個 frequency bin 的 dB 值
    func performFFT(samples: [Float]) -> [Float] {
        
        let halfSize = fftSize / 2
        
        var real = [Float](repeating: 0, count: halfSize)
        var imag = [Float](repeating: 0, count: halfSize)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        
        samples.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
            }
        }
        
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        var magnitudes = [Float](repeating: 0, count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
        
        var scale: Float = 1.0 / Float(fftSize)
        var normalized = [Float](repeating: 0, count: halfSize)
        vDSP_vsmul(magnitudes, 1, &scale, &normalized, 1, vDSP_Length(halfSize))
        
        var dbValues = [Float](repeating: 0, count: halfSize)
        var zero: Float = 1e-20
        vDSP_vdbcon(normalized, 1, &zero, &dbValues, 1, vDSP_Length(halfSize), 0)
        
        return dbValues
    }
    
    /// 將完整頻譜切成多個對數分布的 bar
    /// - Parameters:
    ///   - spectrum: FFT 產生的頻譜資料
    ///   - sampleRate: 取樣率
    ///   - minFrequency: 最低分析頻率
    ///   - maxFrequency: 最高分析頻率
    /// - Returns: 每個 bar 的頻率範圍與振幅
    func splitIntoBars(spectrum: [Float], sampleRate: Double, minFrequency: Float, maxFrequency: Float) -> [(lowerFrequency: Float, upperFrequency: Float, amplitude: Float)] {
        
        let nyquist = Float(sampleRate / 2.0)
        let clampedMax = min(maxFrequency, nyquist)
        let clampedMin = max(minFrequency, 1.0)
        
        guard clampedMax > clampedMin else { return Array(repeating: (0, 0, minDB), count: barCount) }
        
        let minLog = log10(clampedMin)
        let maxLog = log10(clampedMax)
        
        return (0..<barCount).map { barIndex in
            
            let startRatio = Float(barIndex) / Float(barCount)
            let endRatio = Float(barIndex + 1) / Float(barCount)
            
            let lower = pow(10, minLog + (maxLog - minLog) * startRatio)
            let upper = pow(10, minLog + (maxLog - minLog) * endRatio)
            
            let lowerBin = max(1, Int((Double(lower) / sampleRate) * Double(fftSize)))
            let upperBin = min(spectrum.count - 1, Int((Double(upper) / sampleRate) * Double(fftSize)))
            
            guard upperBin >= lowerBin else { return (lower, upper, minDB) }
            
            let slice = spectrum[lowerBin...upperBin]
            let amplitude = slice.max() ?? minDB
            
            return (lower, upper, amplitude)
        }
    }
    
    /// 將 dB 值正規化到 0...1
    /// - Parameter db: dB 值
    /// - Returns: 0...1 的振幅值
    func normalizeDB(_ db: Float) -> Float {
        let clamped = min(max(db, minDB), maxDB)
        return (clamped - minDB) / (maxDB - minDB)
    }
    
    /// 對 bar 做平滑處理，避免 UI 抖動
    /// - Parameters:
    ///   - value: 當前值
    ///   - index: bar 索引
    /// - Returns: 平滑後的值
    func smooth(value: Float, index: Int) -> Float {
        
        guard smoothedBars.indices.contains(index) else { return value }
        
        let next = smoothedBars[index] + (value - smoothedBars[index]) * smoothing
        smoothedBars[index] = next
        
        return next
    }
}
