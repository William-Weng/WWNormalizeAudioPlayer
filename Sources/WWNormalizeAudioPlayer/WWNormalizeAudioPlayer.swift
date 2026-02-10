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
    
    public weak var delegate: Deleagte?
    
    public init() { initAudioEngine() }
}

// MARK: - 公開函式
public extension WWNormalizeAudioPlayer {
    
    /// 播放音樂
    /// - Parameters:
    ///   - url: 音樂檔路徑
    ///   - targetDB: 正規化目標值
    ///   - completionHandler: 播放完成後的動作
    func play(with url: URL, targetDB: Float? = -1.0) {
        
        do {
            _  = try audioEngine._start().get()
            audioFile = try AVAudioFile._build(forReading: url).get()
            
            if let targetDB = targetDB {
                let gain = try normalizeGain(audioFile: audioFile, target: targetDB).get()
                equalizerNode.globalGain = gain
            }
            
            playerNode._schedule(audioFile: audioFile, onStop: true) { [self] in
                delegate?.audioPlayer(self, didFinishPlaying: audioFile)
            }
            
            playerNode.play()
            
        } catch {
            delegate?.audioPlayer(self, error: error)
        }
    }
    
    /// 停止播放音樂
    func stop() {
        audioEngine.stop()
        playerNode.stop()
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
}
