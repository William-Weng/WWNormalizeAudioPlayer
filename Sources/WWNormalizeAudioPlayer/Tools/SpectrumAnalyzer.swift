//
//  SpectrumAnalyzer.swift
//  WWNormalizeAudioPlayer
//
//  Created by William.Weng on 2026/6/2.
//

import AVFAudio
import Accelerate

/// 即時頻譜分析器
public extension WWNormalizeAudioPlayer {
        
    /// 這個分析器會使用 AVAudioNode 的 tap 擷取 PCM buffer，再透過 Accelerate / FFT 將時間域訊號轉成頻域資料，你可以用它來產生即時頻譜資料，進一步做視覺化、RMS、dB 轉換或自訂 band 分析
    final class SpectrumAnalyzer {
        
        private let queue = DispatchQueue(label: "io.github.william-weng.WWNormalizeAudioPlayer.spectrum")  // 用來避免 FFT 分析阻塞主執行緒的背景 queue。
        
        private let fftSize: Int            // FFT 取樣長度，必須是 2 的次方，例如 512、1024、2048
        private let barCount: Int           // 頻譜 bar 數量，分析結果會依照這個數量切成對應的頻帶，必須大於 0
        private let log2n: vDSP_Length      // `fftSize` 的 log2 值，供 `vDSP_fft_zrip` 使用
        private let fftSetup: FFTSetup      // FFT 計算所需的 setup 物件
        
        /// 建立頻譜分析器
        public init(fftSize: Int = 1024, barCount: Int = 32) {
            
            precondition(fftSize > 0 && (fftSize & (fftSize - 1)) == 0, "fftSize must be power of 2")
            precondition(barCount > 0, "barCount must be greater than 0")
            
            self.fftSize = fftSize
            self.barCount = barCount
            self.log2n = vDSP_Length(log2(Float(fftSize)))
            
            guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { fatalError("Failed to create FFT setup") }
            
            self.fftSetup = setup
        }
        
        deinit {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
}

// MARK: - 公開函式
public extension WWNormalizeAudioPlayer.SpectrumAnalyzer {
    
    /// 在指定的音訊節點上安裝 tap，開始擷取 PCM buffer 並輸出 raw 頻帶資料
    ///
    /// 這個方法會在背景 queue 中執行 FFT 與頻帶切分，然後把分析後的 `SpectrumBandRaw` 陣列回傳給呼叫端
    ///
    /// - Important: `installTap` 會持續監聽節點輸出，直到你手動呼叫 `removeTap(from:bus:)`
    ///
    /// - Parameters:
    ///   - node: 要安裝 tap 的音訊節點
    ///   - bus: 要監聽的 bus，預設為 `0`
    ///   - sampleRate: 音訊取樣率，用於將 FFT bin 對應到實際頻率
    ///   - minFrequency: 頻譜分析的最低頻率，預設為 `20 Hz`
    ///   - maxFrequency: 頻譜分析的最高頻率；若為 `nil`，則使用 Nyquist frequency
    ///   - handler: 分析完成後的回呼，回傳 raw 頻帶資料 `SpectrumBandRaw` 陣列
    func installRawTap(on node: AVAudioNode, bus: AVAudioNodeBus = 0, sampleRate: Double, minFrequency: Float = 20, maxFrequency: Float? = nil, handler: @escaping WWNormalizeAudioPlayer.SpectrumRawBandsHandler) {
        
        let format = node.outputFormat(forBus: bus)
        let upper = maxFrequency ?? Float(sampleRate / 2.0)
        
        node.installTap(onBus: bus, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            
            guard let self else { return }
            
            self.queue.async {
                let bands = self.analyzeRaw(buffer: buffer, sampleRate: sampleRate, minFrequency: minFrequency, maxFrequency: upper)
                handler(bands)
            }
        }
    }
    
    /// 移除指定音訊節點上的 tap，停止即時頻譜分析
    ///
    /// 當你不再需要接收音訊 buffer 或要重新安裝新的 tap 時，應先呼叫這個方法把舊的 tap 移除
    ///
    /// - Parameters:
    ///   - node: 要移除 tap 的音訊節點
    ///   - bus: 要移除的 bus，預設為 `0`
    func removeTap(from node: AVAudioNode, bus: AVAudioNodeBus = 0) {
        node.removeTap(onBus: bus)
    }
}

// MARK: - 小工具
private extension WWNormalizeAudioPlayer.SpectrumAnalyzer {
    
    /// 分析單一音訊 buffer，輸出原始頻帶資料
    ///
    /// 這個方法會：
    /// 1. 從 `AVAudioPCMBuffer` 取出第一個聲道的浮點樣本
    /// 2. 只使用最後 `fftSize` 個 sample 做分析
    /// 3. 套用 Hann window 以降低頻譜洩漏
    /// 4. 執行 FFT，取得頻域資料
    /// 5. 將 FFT 結果切分成多個 raw 頻帶 `SpectrumBandRaw`
    ///
    /// - Important: 如果 buffer 長度小於 `fftSize`，會直接回傳空陣列
    ///
    /// - Parameters:
    ///   - buffer: 要分析的 PCM buffer
    ///   - sampleRate: 音訊取樣率，用來把 FFT bin 對應回實際頻率
    ///   - minFrequency: 頻譜分析的最低頻率
    ///   - maxFrequency: 頻譜分析的最高頻率
    /// - Returns: 以頻帶切分後的原始頻譜資料
    func analyzeRaw(buffer: AVAudioPCMBuffer, sampleRate: Double, minFrequency: Float, maxFrequency: Float) -> [WWNormalizeAudioPlayer.SpectrumBandRaw] {
        
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength >= fftSize else { return [] }
        
        let startIndex = frameLength - fftSize
        let samples = Array(UnsafeBufferPointer(start: channelData.advanced(by: startIndex), count: fftSize))
        let windowed = applyHannWindow(samples)
        let spectrum = performFFT(samples: windowed)
        
        return splitIntoRawBands(spectrum: spectrum, sampleRate: sampleRate, minFrequency: minFrequency, maxFrequency: maxFrequency)
    }
    
    /// 套用 Hann window 到原始樣本，降低 FFT 的 spectral leakage
    ///
    /// 這個方法會先建立一個 normalized Hann window，再把 window 與輸入樣本逐點相乘，輸出 windowed samples
    ///
    /// - Parameter samples: 原始時域取樣資料
    /// - Returns: 套用 Hann window 後的取樣資料
    func applyHannWindow(_ samples: [Float]) -> [Float] {
        
        var window = [Float](repeating: 0, count: fftSize)
        var result = [Float](repeating: 0, count: fftSize)
        
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &result, 1, vDSP_Length(fftSize))
        
        return result
    }
    
    func performFFT(samples: [Float]) -> [Float] {
        
        let halfSize = fftSize / 2
        
        var real = [Float](repeating: 0, count: halfSize)
        var imag = [Float](repeating: 0, count: halfSize)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        
        samples.withUnsafeBufferPointer { pointer in
            pointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }
        
        var magnitudes = [Float](repeating: 0, count: halfSize)
        var scale: Float = 1.0 / Float(fftSize)
        var normalized = [Float](repeating: 0, count: halfSize)
        
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
        vDSP_vsmul(magnitudes, 1, &scale, &normalized, 1, vDSP_Length(halfSize))
        
        return normalized
    }
    
    /// 對 windowed samples 執行 FFT，並回傳各頻率 bin 的平方振幅值
    ///
    /// 這個方法會先把實數樣本轉成 `DSPSplitComplex`，接著使用 `vDSP_fft_zrip` 執行 real-to-complex FFT，最後透過 `vDSP_zvmags` 計算每個 bin 的 squared magnitude，並做簡單的比例縮放後回傳
    ///
    /// - Important: 輸入 samples 的長度必須與 `fftSize` 相同，且最好已先套用 window
    /// - Parameter samples: 已經套用 window 的時域樣本
    /// - Returns: FFT 後的頻域資料，內容為每個 bin 的平方振幅值
    func splitIntoRawBands(spectrum: [Float], sampleRate: Double, minFrequency: Float, maxFrequency: Float) -> [WWNormalizeAudioPlayer.SpectrumBandRaw] {
        
        let nyquist = Float(sampleRate / 2.0)
        let clampedMax = min(maxFrequency, nyquist)
        let clampedMin = max(minFrequency, 1.0)
        
        guard clampedMax > clampedMin else { return [] }
        
        let minLog = log10(clampedMin)
        let maxLog = log10(clampedMax)
        
        return (0..<barCount).map { index in
            
            let start = Float(index) / Float(barCount)
            let end = Float(index + 1) / Float(barCount)
            let lower = pow(10, minLog + (maxLog - minLog) * start)
            let upper = pow(10, minLog + (maxLog - minLog) * end)
            
            let lowerBin = max(0, min(spectrum.count - 1, Int(lower / nyquist * Float(spectrum.count))))
            let upperBin = max(lowerBin + 1, min(spectrum.count, Int(upper / nyquist * Float(spectrum.count))))
            let values = Array(spectrum[lowerBin..<upperBin])
            
            return .init(index: index, lowerFrequency: lower, upperFrequency: upper, values: values)
        }
    }
}

