//
//  WWNormalizeAudioPlayer.swift
//  WWNormalizeAudioPlayer
//
//  Created by William.Weng on 2026/2/10.
//

import AVFoundation
import Accelerate

// MARK: - 音量正規化聲音播放器
open class WWNormalizeAudioPlayer {
    
    public weak var delegate: Delegate?
    public var preferredFrameRateRange: CAFrameRateRange = .init(minimum: 5, maximum: 5)

    public private(set) var audioFile: AVAudioFile?

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var equalizerNode: AVAudioUnitEQ?
    
    private var currentTrackIndex: Int = 0
    private var audioURLs: [URL] = []
    private var completedTracksDuration: TimeInterval = 0
    
    private weak var displayLink: CADisplayLink?
    
    public init() { initAudioEngine() }
    
    deinit {
        stopTimer()
        delegate = nil
    }
}

// MARK: - 公開屬性
public extension WWNormalizeAudioPlayer {
    
    var volume: Float {
        get { audioEngine?.mainMixerNode.outputVolume ?? -1.0 }
        set { audioEngine?.mainMixerNode.outputVolume = newValue }
    }
}

// MARK: - 公開函式
public extension WWNormalizeAudioPlayer {
    
    /// 播放指定Bundle中的音頻文件列表
    /// - Parameters:
    ///   - bundle: 資源 Bundle，預設為主要 Bundle (.main)
    ///   - filenames: 音頻文件名陣列
    ///   - targetDB: 目標音量分貝值，nil 則不進行音量正規化
    ///   - callbackType: 播放完成回調類型，預設為 .dataPlayedBack
    /// - Throws: 當檔案不存在或播放失敗時丟出錯誤
    func play(at bundle: Bundle = .main, filenames: [String], targetDB: Float? = nil, callbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack) async {
        
        let urls = filenames.compactMap { bundle.bundleURL.appendingPathComponent($0) }
        try await play(with: urls, targetDB: targetDB, callbackType: callbackType)
    }
    
    /// 播放音頻 URL 陣列，支援順序播放和音量正規化
    /// - Parameters:
    ///   - audioURLs: 音頻文件 URL 陣列
    ///   - targetDB: 目標音量分貝值，nil 則不進行音量正規化
    ///   - callbackType: 播放完成回調類型，預設為 .dataPlayedBack
    /// - Throws: 當音頻檔案無法讀取或播放失敗時丟出錯誤
    func play(with audioURLs: [URL], targetDB: Float? = nil, callbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack) async {
        
        stop()
        
        guard !audioURLs.isEmpty else { return }
        
        self.audioURLs = audioURLs
        
        for url in audioURLs {
                        
            do {
                
                let trackIndex = currentTrackIndex
                let completionType = try await playAudio(url: url, targetDB: targetDB, callbackType: callbackType)
                
                delegate?.audioPlayer(self, didFinishTrackIndex: trackIndex, callbackType: completionType)
                
                completedTracksDuration += currentTrackTotalTime()
                currentTrackIndex += 1
                
            } catch {
                delegate?.audioPlayer(self, error: error)
            }
        }
    }
    
    /// 計算所有音頻文件的總播放時長（單位：秒）
    /// - Returns: 總時長（TimeInterval），如果沒有音頻文件則返回 -1
    func totalTime() -> TimeInterval {
        
        guard !audioURLs.isEmpty else { return -1 }
        
        return audioURLs.reduce(0) { total, url in
            guard let file = try? AVAudioFile(forReading: url) else { return total }
            return total + Double(file.length) / file.fileFormat.sampleRate
        }
    }
    
    /// 停止播放並重置狀態
    func stop() {
        
        currentTrackIndex = 0
        
        playerNode?.stop()
        audioEngine?.stop()
        stopTimer()
    }
    
    /// 恢復播放（從暫停狀態繼續）
    func resume() {
        playerNode?.play()
        startTimer()
    }
    
    /// 暫停播放（保持當前位置）
    func pause() {
        playerNode?.pause()
        audioEngine?.pause()
        stopTimer()
    }
}

// MARK: - 小工具
@objc private extension WWNormalizeAudioPlayer {
    
    func updatePlayTime(_ displayLink: CADisplayLink) {
        
        do {
            let tracTime = currentTrackTotalTime()
            let currentTime = try currentTime()
            
            if currentTrackIndex >= audioURLs.count { stop() }
            delegate?.audioPlayer(self, trackIndex: currentTrackIndex, currentTime: currentTime, trackTime: tracTime)
            
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
}

// MARK: - 小工具
private extension WWNormalizeAudioPlayer {
    
    /// 初始化音樂引擎
    /// - Returns: Result<Bool, Error>
    func initAudioEngine() {
        
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let equalizerNode = AVAudioUnitEQ(numberOfBands: 1)
        
        self.audioEngine = audioEngine
        self.playerNode = playerNode
        self.equalizerNode = equalizerNode
        
        audioEngine.attach(playerNode)
        audioEngine.attach(equalizerNode)

        audioEngine.connect(playerNode, to: equalizerNode, format: nil)
        audioEngine.connect(equalizerNode, to: audioEngine.mainMixerNode, format: nil)

        audioEngine.prepare()
    }
    
    /// [播放音樂](https://cloud.tencent.com/developer/ask/sof/111888173)
    /// - Parameters:
    ///   - url: 音樂檔路徑
    ///   - targetDB: 正規化目標值
    ///   - callbackType: 回傳結束的時機
    func playAudio(url: URL, targetDB: Float?, callbackType: AVAudioPlayerNodeCompletionCallbackType) async throws -> AVAudioPlayerNodeCompletionCallbackType {
        
        guard let audioEngine,
              let playerNode,
              let equalizerNode
        else {
            throw CustomError.playerNodeNotReady
        }
                
        if !audioEngine.isRunning { try audioEngine.start() }
        
        let audioFile = try AVAudioFile(forReading: url)
        self.audioFile = audioFile
        
        if let targetDB {
            let gain = try normalizeGain(audioFile: audioFile, target: targetDB)
            equalizerNode.globalGain = gain
        }
        
        return try await playAudioFile(audioFile: audioFile, playerNode: playerNode, callbackType: callbackType)
    }
    
    /// 排程並播放指定音訊檔案，並在播放完成時透過 continuation 回傳完成型別。
    ///
    /// - Parameters:
    ///   - audioFile: 要播放的音訊檔案
    ///   - playerNode: 實際負責排程與播放的節點
    ///   - callbackType: completion callback 的觸發時機，預設為 `.dataPlayedBack`
    ///
    /// - Returns:
    ///   - 播放完成時實際收到的 `AVAudioPlayerNodeCompletionCallbackType`
    ///
    /// - Throws:
    ///   - `PlaybackError.playerNodeNotReady`：playerNode 尚未準備好
    ///   - 其他由上層呼叫流程拋出的錯誤
    func playAudioFile(audioFile: AVAudioFile, playerNode: AVAudioPlayerNode, callbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack) async throws -> AVAudioPlayerNodeCompletionCallbackType {
        
        return try await withCheckedContinuation { continuation in
            
            playerNode.scheduleFile(audioFile, at: nil, completionCallbackType: callbackType) { [weak self] type in
                continuation.resume(returning: type)
            }
            
            playerNode.play()
            startTimer()
        }
    }
    
    /// 正規化音量
    /// - Parameters:
    ///   - audioFile: 音樂檔
    ///   - target: 目標值
    /// - Returns: Result<Float, Error>
    func normalizeGain(audioFile: AVAudioFile, target targetDB: Float) throws -> Float {
        
        let rmsDB = try audioFile.analyzeChannelRMS()
        return powf(10, (targetDB - rmsDB) / 20)
    }
    
    /// 取得目前曲目的已播放時間（秒）。
    func currentTrackTime() throws -> TimeInterval {
        
        guard let playerNode,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            throw CustomError.currentTimeUnavailable
        }
        
        let seconds = Double(playerTime.sampleTime) / playerTime.sampleRate
        return max(0, min(seconds, currentTrackTotalTime()))
    }
    
    /// 取得目前曲目的總長度（秒）。
    func currentTrackTotalTime() -> TimeInterval {
        guard let audioFile else { return 0 }
        return Double(audioFile.length) / audioFile.fileFormat.sampleRate
    }

    /// 取得整個播放清單目前已播放的時間（秒）。
    func currentTime() throws -> TimeInterval {
        return completedTracksDuration + (try currentTrackTime())
    }
    
    /// 開始計時
    func startTimer() {
        
        stopTimer()
        
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlayTime(_:)))
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.preferredFrameRateRange = preferredFrameRateRange
    }
    
    /// 停止播放時停掉 CADisplayLink
    func stopTimer() {
        
        completedTracksDuration = 0
        
        displayLink?.invalidate()
        displayLink = nil
    }
}
