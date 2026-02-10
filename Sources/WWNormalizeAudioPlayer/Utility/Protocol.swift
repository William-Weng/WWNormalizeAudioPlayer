//
//  Protocol.swift
//  WWNormalizeAudioPlayer
//
//  Created by William.Weng on 2026/2/10.
//

import AVFoundation

// MARK: - NormalizeAudioPlayer.Deleagte
public extension WWNormalizeAudioPlayer {
    
    protocol Deleagte: AnyObject {
        
        /// 音樂播放完成
        /// - Parameters:
        ///   - player: WWNormalizeAudioPlayer
        ///   - callbackType: AVAudioPlayerNodeCompletionCallbackType
        ///   - audioFile: AVAudioFile
        func audioPlayer(_ player: WWNormalizeAudioPlayer, callbackType: AVAudioPlayerNodeCompletionCallbackType, didFinishPlaying audioFile: AVAudioFile)
        
        /// 音樂播放進度
        /// - Parameters:
        ///   - player: WWNormalizeAudioPlayer
        ///   - audioFile: AVAudioFile
        ///   - totalTime: TimeInterval
        ///   - currentTime: TimeInterval
        func audioPlayer(_ player: WWNormalizeAudioPlayer, audioFile: AVAudioFile, totalTime: TimeInterval, currentTime: TimeInterval)
        
        /// 播放相關錯誤
        /// - Parameters:
        ///   - player: WWNormalizeAudioPlayer
        ///   - error: Error
        func audioPlayer(_ player: WWNormalizeAudioPlayer, error: Error)
    }
}
