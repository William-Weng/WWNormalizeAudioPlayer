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
    
    private var audioEngine: AVAudioEngine!
    private var playerNode: AVAudioPlayerNode!
    private var audioFile: AVAudioFile!
    private var equalizerNode: AVAudioUnitEQ!
    private weak var displayLink: CADisplayLink?
    
    public weak var delegate: Deleagte?
    
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
    ///   - AVAudioPlayerNodeCompletionCallbackType: 正規化目標值
    func play(with url: URL, targetDB: Float? = -1.0, callbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack) {
        
        do {
            _  = try audioEngine._start().get()
            audioFile = try AVAudioFile._build(forReading: url).get()
            
            if let targetDB = targetDB {
                let gain = try normalizeGain(audioFile: audioFile, target: targetDB).get()
                equalizerNode.globalGain = gain
            }
            
            playerNode._schedule(audioFile: audioFile, onStop: true, callbackType: callbackType) { [self] type in
                Task { @MainActor in delegate?.audioPlayer(self, callbackType: type, didFinishPlaying: audioFile) }
            }
            
            startTimer()
            playerNode.play()
            
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
    
    /// 停止播放音樂
    func stop() {
        playerNode.stop()
        audioEngine.stop()
        stopTimer()
    }
    
    /// 暫停播放（保留目前進度）
    func pause() {
        playerNode.pause()
        audioEngine.pause()
        stopTimer()
    }
    
    /// 繼續播放（從暫停位置繼續）
    func resume() {
        
        do {
            try audioEngine.start()
            playerNode.play()
            startTimer()
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
    
    /// 設定AVAudioSession
    /// - Parameters:
    ///   - category: AVAudioSession.Category
    ///   - isActive: Bool
    /// - Returns: Result<Bool, Error>
    func setSession(category: AVAudioSession.Category, isActive: Bool = true) -> Result<Bool, Error> {
        return AVAudioSession.sharedInstance()._setCategory(category, isActive: isActive)
    }
}

// MARK: - 小工具
@objc private extension WWNormalizeAudioPlayer {
    
    /// 更新音樂播放時間
    /// - Parameter displayLink: CADisplayLink
    func updatePlayTime(_ displayLink: CADisplayLink) {
        
        let totalTime = totalTime()
        let currentTime = currentTime()
        
        delegate?.audioPlayer(self, audioFile: audioFile, totalTime: totalTime, currentTime: currentTime)
        if (currentTime >= totalTime) { stop() }
    }
}

// MARK: - 小工具
private extension WWNormalizeAudioPlayer {
    
    /// 初始化音樂引擎
    /// - Returns: Result<Bool, Error>
    func initAudioEngine() {
        
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        equalizerNode = AVAudioUnitEQ(numberOfBands: 1)
        
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
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlayTime(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }
        
    /// 停止播放時停掉 CADisplayLink
    func stopTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    /// 取得當前播放時間 (秒)
    /// - Returns: TimeInterval
    func currentTime() -> TimeInterval {
        
        guard let audioFile = audioFile,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return -1
        }
        
        let currentSeconds = Double(playerTime.sampleTime) / playerTime.sampleRate
        return min(currentSeconds, totalTime())
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
