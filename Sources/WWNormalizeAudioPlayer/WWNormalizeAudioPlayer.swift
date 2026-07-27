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
    
    private var audioURLs: [URL] = []
    private var preferredFrameRateRange: CAFrameRateRange = .init(minimum: 5, maximum: 5)
    private var audioFile: AVAudioFile?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    
    private var completedTracksDuration: TimeInterval = 0
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
    ///   - options: `AVAudioSession.CategoryOptions`，用來決定音訊會話的行為，例如是否與其他 App 混音、是否允許藍牙輸出、是否預設輸出到喇叭等。
    /// - Throws: 當音訊會話或引擎初始化失敗時拋出錯誤
    @MainActor
    func prepare(audioURLs: [URL], delegate: Delegate?, preferredFrameRateRange: CAFrameRateRange = .init(minimum: 5, maximum: 5, preferred: 5), options: AVAudioSession.CategoryOptions = []) {
        
        self.delegate = delegate
        self.preferredFrameRateRange = preferredFrameRateRange
        self.audioURLs = audioURLs
        
        do {
            try delegate?.audioPlayer(self, prepare: getTrackInfos())
            try initAudioEngine(options: options)
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
    
    /// 播放音頻 URL 陣列，支援順序播放和音量正規化
    /// - Parameters:
    ///   - index: 從播曲目索引中的哪一首
    ///   - targetDB: 目標音量分貝值，nil 則不進行音量正規化
    ///   - callbackType: 播放完成回調類型，預設為 .dataPlayedBack
    ///   - loop: 是否要循環播放
    ///   - shuffle: 是否要隨曲播放
    /// - Throws: 當音頻檔案無法讀取或播放失敗時丟出錯誤
    func play(at index: Int, targetDB: Float? = nil, callbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack) async throws {
        
        guard let url = audioURLs[safe: index] else { throw CustomError.currentIndexUnavailable }
        
        let audioFile = try AVAudioFile(forReading: url)
        self.audioFile = audioFile
        
        let completionType = try await playAudio(audioFile: audioFile, targetDB: targetDB, callbackType: callbackType)
        await stop()
        await delegate?.audioPlayer(self, didFinished: completionType)
    }
    
    /// 停止播放並重置狀態
    @MainActor
    func stop() {
        
        playbackState = .stopped
        completedTracksDuration = 0
        
        playerNode?.stop()
        audioEngine?.stop()
        stopTimer()
    }
    
    /// 恢復播放（從暫停狀態繼續）
    @MainActor
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
}

// MARK: - @objc
@objc private extension WWNormalizeAudioPlayer {
    
    /// 更新播放進度時間
    /// - Parameter displayLink: 由 CADisplayLink 觸發的更新回呼
    /// - Note: 此方法通常用於定期刷新目前播放時間並通知 delegate
    @MainActor
    func updatePlayTime(_ displayLink: CADisplayLink) {
        
        do {
            let currentTime = try currentTrackTime()
            let trackTime = currentTrackTotalTime()
            delegate?.audioPlayer(self, isPlaying: currentTime, trackTime: trackTime)
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
}

// MARK: - 小工具
private extension WWNormalizeAudioPlayer {
    
    /// 初始化音樂引擎
    /// - Parameter options: AVAudioSession.CategoryOptions
    func initAudioEngine(options: AVAudioSession.CategoryOptions) throws {
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playback, mode: .default, options: options)
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
        
        audioEngine.connect(equalizer.audioNode, to: audioEngine.mainMixerNode, format: nil)
        audioEngine.connect(playerNode, to: equalizer.audioNode, format: nil)

        equalizer.setEnabled(true)
        equalizer.reset()
        
        audioEngine.prepare()
    }
    
    /// 取得所有音訊的長度資訊
    /// - Returns: [音訊的長度資訊]
    func getTrackInfos() -> [TrackInformation] {
        
        audioURLs.compactMap { url in
            let duration = try? trackTime(with: url)
            return .init(url: url, duration: duration ?? -1)
        }
    }
    
    /// [播放音樂](https://cloud.tencent.com/developer/ask/sof/111888173)
    /// - Parameters:
    ///   - audioFile: 音樂檔物件
    ///   - targetDB: 正規化目標值
    ///   - callbackType: 回傳結束的時機
    func playAudio(audioFile: AVAudioFile, targetDB: Float?, callbackType: AVAudioPlayerNodeCompletionCallbackType) async throws -> AVAudioPlayerNodeCompletionCallbackType {
        
        guard let audioEngine,
              let playerNode
        else {
            throw CustomError.playerNodeNotReady
        }
        
        if !audioEngine.isRunning { try audioEngine.start() }
        
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
    
    /// 計算所有音頻文件的總播放時長（單位：秒）
    /// - Returns: 總時長（TimeInterval），如果沒有音頻文件則返回 -1
    func totalTime() -> TimeInterval {
        
        guard !audioURLs.isEmpty else { return -1 }
        
        return audioURLs.reduce(0) { total, url in
            let time = try? trackTime(with: url)
            return total + (time ?? 0)
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
    
    /// 取得該音軌聲音的時間長度 (秒)
    /// - Parameter url: URL
    /// - Returns: TimeInterval
    func trackTime(with url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.fileFormat.sampleRate
    }
    
    /// 取得目前曲目的總長度（秒）
    func currentTrackTotalTime() -> TimeInterval {
        guard let audioFile else { return 0 }
        return Double(audioFile.length) / audioFile.fileFormat.sampleRate
    }
    
    /// 開始計時
    func startTimer() {
        
        guard (delegate != nil) else { return }
        
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
