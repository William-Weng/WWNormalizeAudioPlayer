//
//  Extension.swift
//  WWNormalizeAudioPlayer
//
//  Created by William.Weng on 2026/2/10.
//

import AVFAudio
import Accelerate


// MARK: - Collection (override function)
extension Collection {

    /// [為Array加上安全取值特性 => nil](https://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings)
    subscript(safe index: Index) -> Element? { return indices.contains(index) ? self[index] : nil }
}

// MARK: - AVAudioFile
extension AVAudioFile {
    
    /// 根據目標分貝值計算需要補多少增益
    /// - Parameter targetDB: 目標分貝值
    /// - Returns: 建議套用的增益值（dB）
    func normalizationGain(targetDB: Float) throws -> Float {
        
        let currentDB = try analyzeChannelRMS()
        return targetDB - currentDB
    }
}

// MARK: - AVAudioFile
private extension AVAudioFile {
    
    /// [把音樂檔案放滿到PCMBuffer內](https://blog.csdn.net/chennai1101/article/details/122621274)
    /// - Parameters:
    ///   - framePosition: 聲音框架位置
    ///   - buffer: AVAudioPCMBuffer
    /// - Returns: Result<Bool, Error>
    func readFile(from framePosition: AVAudioFramePosition, into buffer: AVAudioPCMBuffer) throws {
        
        let capacity = AVAudioFrameCount(length)
        self.framePosition = framePosition
        
        try read(into: buffer, frameCount: capacity)
    }
    
    /// 分析檔案最大音量的RMS分貝值 (DB)
    /// - Returns: Result<Float, Error>
    func analyzeChannelRMS(`default`: Float = -100) throws -> Float {
        
        let rms = try channelRMS()
        var rmsDB: Float = `default`
        
        if let rms = rms, rms > 0 { rmsDB = 20 * log10(rms) }
        return rmsDB
    }
    
    /// 分析檔案最大音量的RMS值
    /// - Returns: Result<Float, Error>
    func channelRMS() throws -> Float?{
        
        guard let buffer = AVAudioPCMBuffer.build(of: self) else { return nil }
        try readFile(from: 0, into: buffer)
        
        return buffer.channelRMS()
    }
}

// MARK: - AVAudioPCMBuffer (static)
private extension AVAudioPCMBuffer {
    
    /// 建立一個跟檔案一樣大的PCMBuffer
    /// - Parameter file: AVAudioFile
    /// - Returns: AVAudioPCMBuffer?
    static func build(of file: AVAudioFile) -> AVAudioPCMBuffer? {
        
        let capacity = AVAudioFrameCount(file.length)
        let format = file.processingFormat
        
        return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)
    }
}

// MARK: - AVAudioPCMBuffer
private extension AVAudioPCMBuffer {
    
    /// [分析檔案最大音量的方均根值 - RMS](https://medium.com/blendvision/有關audio-normalization兩三事-dca62497e197)
    /// - Returns: Float
    func channelRMS() -> Float {
        
        var rms: Float = 0.0
        let channelCount = Int(format.channelCount)

        for index in 0..<channelCount {
            
            guard let channelData = floatChannelData?[index] else { continue }
            
            var channelRMS: Float = 0.0
            vDSP_rmsqv(channelData, 1, &channelRMS, vDSP_Length(frameLength))
            rms = max(rms, channelRMS)
        }
        
        return rms
    }
    
    /// [分析檔案最大音量值 - Peak](https://medium.com/blendvision/有關audio-normalization兩三事-下-c74f42ccc3f6)
    /// - Returns: Float
    func channelPeakAmplitude() -> Float {
        
        var peak: Float = 0.0
        let channelCount = Int(format.channelCount)

        for index in 0..<channelCount {
            
            guard let channelData = floatChannelData?[index] else { continue }
            
            var channelPeak: Float = 0.0
            vDSP_maxv(channelData, 1, &channelPeak, vDSP_Length(frameLength))
            peak = max(peak, channelPeak)
        }
        
        return peak
    }
}
