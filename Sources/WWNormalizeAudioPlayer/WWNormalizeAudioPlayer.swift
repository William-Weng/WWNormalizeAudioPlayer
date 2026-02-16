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
    
    public weak var delegate: Deleagte?

    public private(set) var audioFile: AVAudioFile?
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var equalizerNode: AVAudioUnitEQ?
    
    private weak var displayLink: CADisplayLink?
    
    public var volume: Float {
        get { audioEngine?.mainMixerNode.outputVolume ?? -1.0 }
        set { audioEngine?.mainMixerNode.outputVolume = newValue }
    }
    
    public var preferredFrameRateRange: CAFrameRateRange? = CAFrameRateRange(minimum: 5, maximum: 5)
    
    public init() { initAudioEngine() }
    
    deinit {
        delegate = nil
        stopTimer()
    }
}

// MARK: - 公開函式
public extension WWNormalizeAudioPlayer {
    
    /// [播放音樂](https://cloud.tencent.com/developer/ask/sof/111888173)
    /// - Parameters:
    ///   - url: 音樂檔路徑
    ///   - targetDB: 正規化目標值
    ///   - callbackType: 回傳結束的時機
    func play(with url: URL, targetDB: Float? = -1.0, callbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack) {
        
        guard let audioEngine = audioEngine,
              let playerNode = playerNode,
              let equalizerNode = equalizerNode
        else {
            return
        }
        
        do {
            _  = try audioEngine._start().get()
            
            let audioFile = try AVAudioFile._build(forReading: url).get()
            self.audioFile = audioFile
            
            if let targetDB = targetDB {
                let gain = try normalizeGain(audioFile: audioFile, target: targetDB).get()
                equalizerNode.globalGain = gain
            }
            
            playerNode._schedule(audioFile: audioFile, callbackType: callbackType) { [self] type in
                Task { @MainActor in delegate?.audioPlayer(self, callbackType: type, didFinishPlaying: audioFile) }
            }
            
            if (preferredFrameRateRange != nil) { startTimer() }
            playerNode.play()
            
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
    
    /// 停止播放音樂
    func stop() {
        playerNode?.stop()
        audioEngine?.stop()
        stopTimer()
    }
    
    /// 繼續播放（從暫停位置繼續）
    func resume() {
        
        do {
            try audioEngine?.start()
            playerNode?.play()
            startTimer()
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
    
    /// 暫停播放（保留目前進度）
    func pause() {
        playerNode?.pause()
        audioEngine?.pause()
        stopTimer()
    }
    
    /// 取得當前播放時間 (秒)
    /// - Returns: TimeInterval
    func currentTime() -> Result<TimeInterval, Error> {
        
        guard let nodeTime = playerNode?.lastRenderTime,
              let playerTime = playerNode?.playerTime(forNodeTime: nodeTime)
        else {
            return .failure(CustomError.noCurrentTime)
        }
        
        let currentSeconds = Double(playerTime.sampleTime) / playerTime.sampleRate
        return .success(min(currentSeconds, totalTime()))
    }
    
    /// 取得總播放時間 (秒)
    /// - Returns: TimeInterval
    func totalTime() -> TimeInterval {
        
        guard let audioFile = audioFile else { return -1 }
        
        let sampleRate = audioFile.fileFormat.sampleRate
        let length = Double(audioFile.length)
        
        return length / sampleRate
    }
}

// MARK: - 小工具
@objc private extension WWNormalizeAudioPlayer {
    
    /// 更新音樂播放時間
    /// - Parameter displayLink: CADisplayLink
    func updatePlayTime(_ displayLink: CADisplayLink) {
        
        do {
            let totalTime = totalTime()
            let currentTime = try currentTime().get()
            
            if let delegate = delegate, let audioFile = audioFile {
                delegate.audioPlayer(self, audioFile: audioFile, totalTime: totalTime, currentTime: currentTime)
            }
            
            if (currentTime >= totalTime) { stop() }
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
        
        audioEngine
            ._attachNode(equalizerNode, connectTo: audioEngine.mainMixerNode)
            ._attachNode(playerNode, connectTo: equalizerNode)
            .prepare()
    }
    
    /// 正規化音量
    /// - Parameters:
    ///   - audioFile: 音樂檔
    ///   - target: 目標值
    /// - Returns: Result<Float, Error>
    func normalizeGain(audioFile: AVAudioFile, target targetDB: Float) -> Result<Float, Error> {
        
        switch audioFile._analyzeChannelRMS() {
        case .failure(let error): return .failure(error)
        case .success(let rmsDB):
            let normalizeGain = powf(10, (targetDB - rmsDB) / 20)
            return .success(normalizeGain)
        }
    }
    
    /// 開始計時
    func startTimer() {
        
        stopTimer()
        
        if let preferredFrameRateRange = preferredFrameRateRange {
            displayLink = CADisplayLink(target: self, selector: #selector(updatePlayTime(_:)))
            displayLink?.add(to: .main, forMode: .common)
            displayLink?.preferredFrameRateRange = preferredFrameRateRange
        }
    }
    
    /// 停止播放時停掉 CADisplayLink
    func stopTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }
}
