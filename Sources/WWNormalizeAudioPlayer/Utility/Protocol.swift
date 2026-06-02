//
//  Protocol.swift
//  WWNormalizeAudioPlayer
//
//  Created by William.Weng on 2026/2/10.
//

import AVFoundation

// MARK: - WWNormalizeAudioPlayer.Delegate
public extension WWNormalizeAudioPlayer {
    
    /// WWNormalizeAudioPlayer 的代理協議，用於通知播放狀態、進度與錯誤
    /// - Note: 使用 `AnyObject` 限制為類別協議，支援弱引用避免循環引用
    protocol Delegate: AnyObject {
        
        /// 當音頻播放進度更新時呼叫（通常由計時器定期觸發）
        /// - Parameters:
        ///   - player: 播放器實例
        ///   - trackIndex: 當前播放的軌道索引（從 0 開始）
        ///   - currentTime: 當前播放位置（單位：秒）
        ///   - tracTime: 當前軌道的總時長（單位：秒）
        func audioPlayer(_ player: WWNormalizeAudioPlayer, trackIndex: Int, currentTime: TimeInterval, trackTime: TimeInterval)

        /// 當單個軌道播放完成時呼叫
        /// - Parameters:
        ///   - player: 播放器實例
        ///   - trackIndex: 已完成播放的軌道索引
        ///   - callbackType: 播放完成的回調類型（例如 .dataPlayedBack）
        func audioPlayer(_ player: WWNormalizeAudioPlayer, didFinishTrackIndex trackIndex: Int, callbackType: AVAudioPlayerNodeCompletionCallbackType)

        /// 當播放過程中發生錯誤時呼叫
        /// - Parameters:
        ///   - player: 播放器實例
        ///   - error: 發生的錯誤
        func audioPlayer(_ player: WWNormalizeAudioPlayer, error: Error)
    }
}
