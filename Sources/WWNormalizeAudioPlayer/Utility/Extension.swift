//
//  Extension.swift
//  WWNormalizeAudioPlayer
//
//  Created by William.Weng on 2026/2/10.
//

import AVFAudio
import Accelerate

// MARK - AVAudioSession
extension AVAudioSession {
    
    typealias AudioSystemParameter = (outputVolume: Float, isOtherAudioPlaying: Bool)
    
    /// 檢查系統音量 + 是否靜音
    func _systemParameter() -> AudioSystemParameter  {
        return (outputVolume: outputVolume, isOtherAudioPlaying: isOtherAudioPlaying)
    }
    
    /// [設定要使用的功能 (播放 / 錄音 / …)](https://cloud.tencent.com/developer/ask/sof/112809922)
    /// - Parameters:
    ///   - category: 功能項目
    ///   - isActive: 是否運行
    /// - Returns: Result<Bool, Error>
    func _setCategory(_ category: Category, isActive: Bool) -> Result<Bool, Error> {
        
        do {
            try setCategory(category)
            try setActive(isActive)
            return .success(true)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - AVAudioEngine
extension AVAudioEngine {
    
    /// 啟動引擎
    /// - Returns: Result<Bool, Error>
    func _start() -> Result<Bool, Error> {
        
        do {
            try start()
            return .success(true)
        } catch {
            return .failure(error)
        }
    }
    
    /// 加上音效節點
    /// - Parameter node: AVAudioNode
    /// - Returns: Self
    func _attach(node: AVAudioNode) -> Self {
        attach(node)
        return self
    }
    
    /// [連接音效節點](https://cloud.tencent.com/developer/ask/sof/112809922)
    /// - Parameters:
    ///   - node: 來源節點
    ///   - targetNode: 目的節點
    ///   - format: 格式設定
    /// - Returns: Self
    func _connect(node: AVAudioNode, to targetNode: AVAudioNode, format: AVAudioFormat? = nil) -> Self {
        connect(node, to: targetNode, format: format)
        return self
    }
    
    /// [加上音效節點，並且連接](https://blog.csdn.net/chennai1101/article/details/122621274)
    /// - Parameters:
    ///   - node: 來源節點
    ///   - targetNode: 目的節點
    ///   - format: 格式設定
    /// - Returns: Self
    func _attachNode(_ node: AVAudioNode, connectTo targetNode: AVAudioNode, format: AVAudioFormat? = nil) -> Self {
        return self._attach(node: node)._connect(node: node, to: targetNode)
    }
}

// MARK: - AVAudioFile (static)
extension AVAudioFile {
    
    /// 讀取音效檔案
    /// - Parameter url: 音效檔案位置
    /// - Returns: Result<AVAudioFile, Error>
    static func _build(forReading url: URL) -> Result<AVAudioFile, Error> {
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            return .success(audioFile)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - AVAudioFile
extension AVAudioFile {
    
    /// [把音樂檔案放滿到PCMBuffer內](https://blog.csdn.net/chennai1101/article/details/122621274)
    /// - Parameters:
    ///   - framePosition: 聲音框架位置
    ///   - buffer: AVAudioPCMBuffer
    /// - Returns: Result<Bool, Error>
    func _read(from framePosition: AVAudioFramePosition = 0, into buffer: AVAudioPCMBuffer) -> Result<Bool, Error> {
        
        let capacity = AVAudioFrameCount(length)
        self.framePosition = framePosition
        
        do {
            try read(into: buffer, frameCount: capacity)
            return .success(true)
        } catch {
            return .failure(error)
        }
    }
    
    /// 分析檔案最大音量的RMS值
    /// - Returns: Result<Float, Error>
    func _channelRMS() -> Result<Float?, Error> {
        
        guard let buffer = AVAudioPCMBuffer._build(of: self) else { return .success(nil) }

        switch _read(into: buffer) {
        case .failure(let error): return .failure(error)
        case .success(_): return .success(buffer._channelRMS())
        }
    }
    
    /// 分析檔案最大音量的RMS分貝值 (DB)
    /// - Returns: Result<Float, Error>
    func _analyzeChannelRMS(`default`: Float = -100) -> Result<Float, Error> {
        
        switch _channelRMS() {
        case .failure(let error): return .failure(error)
        case .success(let rms):
            
            var rmsDB: Float = `default`
            
            if let rms = rms, rms > 0 { rmsDB = 20 * log10(rms) }
            return .success(rmsDB)
        }
    }
}

// MARK: - AVAudioPlayerNode
extension AVAudioPlayerNode {
    
    /// 排定音樂檔案
    /// - Parameters:
    ///   - audioFile: 音效檔案
    ///   - onStop: 是否停止
    ///   - when: 開始時間
    ///   - callbackType: 哪個階段發出完成訊息
    ///   - completionHandler: 完成後的處理
    func _schedule(audioFile: AVAudioFile, onStop: Bool = false, at when: AVAudioTime? = nil, callbackType: AVAudioPlayerNodeCompletionCallbackType, completionHandler: AVAudioPlayerNodeCompletionHandler?) {
        if (onStop) { stop() }
        scheduleFile(audioFile, at: when, completionCallbackType: callbackType, completionHandler: completionHandler)
    }
}

// MARK: - AVAudioPCMBuffer (static)
extension AVAudioPCMBuffer {
    
    /// 建立一個跟檔案一樣大的PCMBuffer
    /// - Parameter file: AVAudioFile
    /// - Returns: AVAudioPCMBuffer?
    static func _build(of file: AVAudioFile) -> AVAudioPCMBuffer? {
        
        let capacity = AVAudioFrameCount(file.length)
        let format = file.processingFormat
        
        return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)
    }
}

// MARK: - AVAudioPCMBuffer
extension AVAudioPCMBuffer {
    
    /// [分析檔案最大音量的方均根值 - RMS](https://medium.com/blendvision/有關audio-normalization兩三事-dca62497e197)
    /// - Returns: Float
    func _channelRMS() -> Float {
        
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
    func _channelPeakAmplitude() -> Float {
        
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
