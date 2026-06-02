//
//  Equalizer.swift
//  WWNormalizeAudioPlayer
//
//  Created by William.Weng on 2026/6/2.
//

import AVFAudio

/// 音訊等化器封裝
/// - Note: 透過 AVAudioUnitEQ 提供預設音色、單一頻段調整與濾波器型態切換
extension WWNormalizeAudioPlayer {
    
    public class Equalizer {
        
        let node: AVAudioUnitEQ         // 底層的 AVAudioUnitEQ 實例
        let frequencies: [Float]        // 預設頻段對應的中心頻率
        
        /// 建立等化器
        /// - Parameter frequencies: 各 band 的預設頻率，預設為 10 段常見配置
        init(frequencies: [Float] = [32, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]) {
            self.frequencies = frequencies
            self.node = AVAudioUnitEQ(numberOfBands: frequencies.count)
            configureDefaultBands()
        }
    }
}

// MARK: - 公開屬性
public extension WWNormalizeAudioPlayer.Equalizer {
    
    /// 目前整體 EQ 的增益值
    var globalGain: Float {
        get { node.globalGain }
        set { node.globalGain = newValue }
    }
}

// MARK: - 公開函式
public extension WWNormalizeAudioPlayer.Equalizer {
    
    /// 啟用或停用等化器
    /// - Parameter enabled: true 表示啟用，false 表示略過 EQ
    func setEnabled(_ enabled: Bool) { node.bypass = !enabled }
    
    /// 重置為平坦模式
    func reset() { preset(.flat) }
        
    /// 設定某個 band 的增益
    /// - Parameters:
    ///   - index: band 索引
    ///   - gain: 增益值，單位 dB
    func bandGain(index: Int, gain: Float) throws {
        guard node.bands.indices.contains(index) else { throw WWNormalizeAudioPlayer.CustomError.equalizerBandIndexOutOfRange(index: index, count: node.bands.count) }
        node.bands[index].gain = gain
    }
    
    /// 設定某個 band 的中心頻率
    /// - Parameters:
    ///   - index: band 索引
    ///   - frequency: 頻率，單位 Hz
    func bandFrequency(index: Int, frequency: Float) throws {
        guard node.bands.indices.contains(index) else { throw WWNormalizeAudioPlayer.CustomError.equalizerBandIndexOutOfRange(index: index, count: node.bands.count) }
        node.bands[index].frequency = frequency
    }
    
    /// 設定某個 band 的頻寬
    /// - Parameters:
    ///   - index: band 索引
    ///   - bandwidth: 頻寬，單位 octaves
    func bandBandwidth(index: Int, bandwidth: Float) throws {
        guard node.bands.indices.contains(index) else { throw WWNormalizeAudioPlayer.CustomError.equalizerBandIndexOutOfRange(index: index, count: node.bands.count) }
        node.bands[index].bandwidth = bandwidth
    }
    
    /// 設定某個 band 的濾波器類型
    /// - Parameters:
    ///   - index: band 索引
    ///   - type: 濾波器類型
    func bandType(index: Int, type: WWNormalizeAudioPlayer.EqualizerBandType) throws {
        guard node.bands.indices.contains(index) else { throw WWNormalizeAudioPlayer.CustomError.equalizerBandIndexOutOfRange(index: index, count: node.bands.count) }
        node.bands[index].filterType = map(type)
    }
    
    /// 設定某個 band 是否 bypass
    /// - Parameters:
    ///   - index: band 索引
    ///   - bypass: true 表示跳過該 band
    func bandBypass(index: Int, bypass: Bool) throws {
        guard node.bands.indices.contains(index) else { throw WWNormalizeAudioPlayer.CustomError.equalizerBandIndexOutOfRange(index: index, count: node.bands.count) }
        node.bands[index].bypass = bypass
    }
        
    /// 一次設定某個 band 的完整參數
    /// - Parameters:
    ///   - index: band 索引
    ///   - type: 濾波器類型
    ///   - frequency: 頻率
    ///   - bandwidth: 頻寬
    ///   - gain: 增益
    ///   - bypass: 是否略過
    func band(index: Int, type: WWNormalizeAudioPlayer.EqualizerBandType? = nil, frequency: Float? = nil, bandwidth: Float? = nil, gain: Float? = nil, bypass: Bool? = nil) throws {
        
        guard node.bands.indices.contains(index) else { throw WWNormalizeAudioPlayer.CustomError.equalizerBandIndexOutOfRange(index: index, count: node.bands.count) }

        let band = node.bands[index]
        
        if let type { band.filterType = map(type) }
        if let frequency { band.frequency = frequency }
        if let bandwidth { band.bandwidth = bandwidth }
        if let gain { band.gain = gain }
        if let bypass { band.bypass = bypass }
    }
    
    /// 設定預設音色
    /// - Parameter preset: 預設模式
    func preset(_ preset: WWNormalizeAudioPlayer.EqualizerPreset) {
        
        switch preset {
        case .flat: apply(gains: Array(repeating: 0, count: frequencies.count)); node.globalGain = 0
        case .bassBoost: apply(gains: [6, 5, 3, 1, 0, 0, -1, -2, -2, -3])
        case .bassCut: apply(gains: [-6, -5, -3, -1, 0, 0, 0, 0, 0, 0])
        case .trebleBoost: apply(gains: [-3, -2, -1, 0, 0, 1, 3, 5, 6, 7])
        case .trebleCut: apply(gains: [0, 0, 0, 0, 0, -1, -3, -5, -6, -7])
        case .vocalBoost: apply(gains: [-2, -1, 0, 2, 4, 5, 4, 2, 0, -1])
        case .custom(let gains): apply(gains: gains)
        }
    }
    
    /// 依據音訊檔案的 RMS 分貝值，計算並套用總增益
    /// - Parameters:
    ///   - file: 音訊檔案
    ///   - targetDB: 目標分貝值
    ///   - clampRange: 可限制最大/最小增益，避免輸出過大或過小
    /// - Returns: 實際套用的 globalGain
    @discardableResult
    func normalizationGain(of file: AVAudioFile, targetDB: Float, clampRange: ClosedRange<Float>? = nil) throws -> Float {
        
        var gain = try file.normalizationGain(targetDB: targetDB)
        
        if let clampRange { gain = min(max(gain, clampRange.lowerBound), clampRange.upperBound) }
        globalGain = gain
        
        return gain
    }
}

// MARK: - 小工具
private extension WWNormalizeAudioPlayer.Equalizer {
    
    /// 初始化時設定每個 band 的預設參數
    func configureDefaultBands() {
        
        for (index, band) in node.bands.enumerated() {
            band.bypass = false
            band.filterType = .parametric
            band.frequency = frequencies[index]
            band.bandwidth = 1.0
            band.gain = 0.0
        }
        
        node.globalGain = 0.0
    }
    
    /// 套用一組增益值到所有 bands
    /// - Parameter gains: 每個 band 的 gain 值
    func apply(gains: [Float]) {
        
        for (index, band) in node.bands.enumerated() {
            band.bypass = false
            band.filterType = .parametric
            band.frequency = frequencies[index]
            band.bandwidth = 1.0
            band.gain = gains.indices.contains(index) ? gains[index] : 0
        }
    }
    
    /// 將自訂 band type 映射到 AVAudioUnitEQFilterType
    /// - Parameter type: 自訂 band 類型
    /// - Returns: 對應的 AVAudioUnitEQFilterType
    func map(_ type: WWNormalizeAudioPlayer.EqualizerBandType) -> AVAudioUnitEQFilterType {
        
        switch type {
        case .parametric: return .parametric
        case .lowPass: return .lowPass
        case .highPass: return .highPass
        case .resonantLowPass: return .resonantLowPass
        case .resonantHighPass: return .resonantHighPass
        case .bandPass: return .bandPass
        case .bandStop: return .bandStop
        case .lowShelf: return .lowShelf
        case .highShelf: return .highShelf
        case .resonantLowShelf: return .resonantLowShelf
        case .resonantHighShelf: return .resonantHighShelf
        }
    }
}
