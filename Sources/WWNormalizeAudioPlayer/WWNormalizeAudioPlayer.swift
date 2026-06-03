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
    
    public let equalizer: Equalizer = .init()
    
    private weak var delegate: Delegate?
    
    private var preferredFrameRateRange: CAFrameRateRange = .init(minimum: 5, maximum: 5)
    private var audioFile: AVAudioFile?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    private var currentTrackIndex: Int = 0
    private var audioURLs: [URL] = []
    private var completedTracksDuration: TimeInterval = 0
    private var isLoop: Bool = false
    private var playbackState: PlaybackState = .idle
    
    private weak var displayLink: CADisplayLink?
    
    public init() {}
    
    deinit {
        stopTimer()
        delegate = nil
    }
}

// MARK: - 公開屬性
public extension WWNormalizeAudioPlayer {
    
    /// 調整播放器音量，範圍為 `0.0 ~ 1.0`
    var volume: Float {
        get { audioEngine?.mainMixerNode.outputVolume ?? -1.0 }
        set { audioEngine?.mainMixerNode.outputVolume = newValue }
    }
    
    /// AVAudioUnitEQ 實例
    var audioNode: AVAudioUnitEQ {
        equalizer.audioNode
    }
}

// MARK: - 公開函式
public extension WWNormalizeAudioPlayer {
    
    /// 設定代理與更新頻率，並初始化音訊引擎
    /// - Parameters:
    ///   - delegate: 播放器代理
    ///   - preferredFrameRateRange: 進度更新的幀率範圍
    /// - Throws: 當音訊會話或引擎初始化失敗時拋出錯誤
    func configure(delegate: Delegate, preferredFrameRateRange: CAFrameRateRange = .init(minimum: 5, maximum: 5, preferred: 5)) throws {
        self.delegate = delegate
        self.preferredFrameRateRange = preferredFrameRateRange
        try initAudioEngine()
    }
    
    /// 播放指定Bundle中的音頻文件列表
    /// - Parameters:
    ///   - bundle: 資源 Bundle，預設為主要 Bundle (.main)
    ///   - filenames: 音頻文件名陣列
    ///   - targetDB: 目標音量分貝值，nil 則不進行音量正規化
    ///   - callbackType: 播放完成回調類型，預設為 .dataPlayedBack
    ///   - loop: 是否要循環播放
    ///   - shuffle: 是否要隨曲播放
    /// - Throws: 當檔案不存在或播放失敗時丟出錯誤
    func play(at bundle: Bundle = .main, filenames: [String], targetDB: Float? = nil, callbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack, loop: Bool = false, shuffle: Bool = false) async {
        
        let urls = filenames.compactMap { bundle.bundleURL.appendingPathComponent($0) }
        try await play(with: urls, targetDB: targetDB, callbackType: callbackType, loop: loop, shuffle: shuffle)
    }
    
    /// 播放音頻 URL 陣列，支援順序播放和音量正規化
    /// - Parameters:
    ///   - audioURLs: 音頻文件 URL 陣列
    ///   - targetDB: 目標音量分貝值，nil 則不進行音量正規化
    ///   - callbackType: 播放完成回調類型，預設為 .dataPlayedBack
    ///   - loop: 是否要循環播放
    ///   - shuffle: 是否要隨曲播放
    /// - Throws: 當音頻檔案無法讀取或播放失敗時丟出錯誤
    func play(with audioURLs: [URL], targetDB: Float? = nil, callbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack, loop: Bool = false, shuffle: Bool = false) async {
        
        stop()
        
        guard !audioURLs.isEmpty else { return }
        
        self.audioURLs = audioURLs
        self.isLoop = loop
        self.playbackState = .playing
        
        repeat {
            
            let playURLs = shuffle ? self.audioURLs.shuffled() : self.audioURLs
            
            currentTrackIndex = 0
            completedTracksDuration = 0
            
            for url in playURLs {
                
                guard playbackState == .playing else { return }
                
                let trackIndex = currentTrackIndex
                
                do {
                    let completionType = try await playAudio(url: url, targetDB: targetDB, callbackType: callbackType)

                    delegate?.audioPlayer(self, didFinishTrackIndex: trackIndex, callbackType: completionType)
                    completedTracksDuration += currentTrackTotalTime()

                } catch {
                    delegate?.audioPlayer(self, error: error)
                }
                
                currentTrackIndex += 1
            }
            
        } while isLoop && playbackState == .playing
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
        
        isLoop = false
        playbackState = .stopped
        currentTrackIndex = 0
        completedTracksDuration = 0
        
        playerNode?.stop()
        audioEngine?.stop()
        stopTimer()
    }
    
    /// 恢復播放（從暫停狀態繼續）
    func resume() {
        
        guard playbackState == .paused else { return }
        
        do {
            playbackState = .playing
            try audioEngine?.start()
            playerNode?.play()
            startTimer()
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
    
    /// 暫停播放（保持當前位置）
    func pause() {
        
        guard playbackState == .playing else { return }
        
        playbackState = .paused
        playerNode?.pause()
        audioEngine?.pause()
        stopTimer()
    }
    
    /// 設定是否要循環播放
    /// - Parameter enabled: 循環播放
    func setLoopEnabled(_ enabled: Bool) {
        isLoop = enabled
    }
}

// MARK: - @objc
@objc private extension WWNormalizeAudioPlayer {
    
    /// 更新播放進度時間
    /// - Parameter displayLink: 由 CADisplayLink 觸發的更新回呼
    /// - Note: 此方法通常用於定期刷新目前播放時間並通知 delegate
    func updatePlayTime(_ displayLink: CADisplayLink) {
        
        do {
            let trackTime = currentTrackTotalTime()
            let currentTime = try currentTime()
            
            if currentTrackIndex >= audioURLs.count { stop() }
            delegate?.audioPlayer(self, trackIndex: currentTrackIndex, currentTime: currentTime, trackTime: trackTime)
            
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
}

// MARK: - 小工具
private extension WWNormalizeAudioPlayer {
    
    /// 初始化音樂引擎
    func initAudioEngine() throws {
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP, .allowAirPlay])
            try audioSession.setActive(true)
        } catch {
            throw CustomError.audioSessionConfigurationFailed
        }
        
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        self.audioEngine = audioEngine
        self.playerNode = playerNode
        
        audioEngine.attach(playerNode)
        audioEngine.attach(equalizer.audioNode)
        
        audioEngine.connect(playerNode, to: equalizer.audioNode, format: nil)
        audioEngine.connect(equalizer.audioNode, to: audioEngine.mainMixerNode, format: nil)
        
        equalizer.setEnabled(true)
        equalizer.reset()
        
        audioEngine.prepare()
    }
    
    /// [播放音樂](https://cloud.tencent.com/developer/ask/sof/111888173)
    /// - Parameters:
    ///   - url: 音樂檔路徑
    ///   - targetDB: 正規化目標值
    ///   - callbackType: 回傳結束的時機
    func playAudio(url: URL, targetDB: Float?, callbackType: AVAudioPlayerNodeCompletionCallbackType) async throws -> AVAudioPlayerNodeCompletionCallbackType {
        
        guard let audioEngine,
              let playerNode
        else {
            throw CustomError.playerNodeNotReady
        }
        
        if !audioEngine.isRunning { try audioEngine.start() }
        
        let audioFile = try AVAudioFile(forReading: url)
        self.audioFile = audioFile
        
        if let targetDB {
            let gainDB = try equalizer.normalizationGain(of: audioFile, targetDB: targetDB)
            equalizer.globalGain = gainDB
        } else {
            equalizer.globalGain = 0
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
    
    /// 取得目前曲目的已播放時間（秒）
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
    
    /// 取得目前曲目的總長度（秒）
    func currentTrackTotalTime() -> TimeInterval {
        guard let audioFile else { return 0 }
        return Double(audioFile.length) / audioFile.fileFormat.sampleRate
    }

    /// 取得整個播放清單目前已播放的時間（秒）
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
