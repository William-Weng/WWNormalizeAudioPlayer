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
    @MainActor
    protocol Delegate: AnyObject {
        
        /// 告知代理：播放器即將開始準備指定的音軌
        ///
        /// 可在此更新播放清單、初始化 UI 狀態，或顯示準備中的提示
        ///
        /// - Parameters:
        ///   - player: 觸發此事件的 `WWNormalizeAudioPlayer` 實例
        ///   - tracks: 即將開始播放的音軌資訊陣列
        func audioPlayer(_ player: WWNormalizeAudioPlayer, prepare tracks: [TrackInformation])
 
        /// 回報目前播放進度
        ///
        /// 通常在播放過程中持續回呼，可用來更新進度條、時間標籤或其他播放相關 UI
        ///
        /// - Parameters:
        ///   - player: 播放器實例
        ///   - currentTime: 當前播放位置，單位為秒
        ///   - trackTime: 目前音軌的總長度，單位為秒
        func audioPlayer(_ player: WWNormalizeAudioPlayer, isPlaying currentTime: TimeInterval, trackTime: TimeInterval)

        /// 告知代理：目前音軌已播放完成
        ///
        /// 可根據 `callbackType` 判斷是自然播放結束，或是其他完成時機所觸發的回呼
        ///
        /// - Parameters:
        ///   - player: 播放器實例
        ///   - callbackType: 播放完成的回調類型，例如 `.dataPlayedBack`
        func audioPlayer(_ player: WWNormalizeAudioPlayer, didFinished callbackType: AVAudioPlayerNodeCompletionCallbackType)

        /// 當播放過程中發生錯誤時呼叫
        ///
        /// 可在此停止播放、顯示錯誤訊息，或記錄除錯資訊
        ///
        /// - Parameters:
        ///   - player: 播放器實例
        ///   - error: 發生的錯誤
        func audioPlayer(_ player: WWNormalizeAudioPlayer, error: Error)
    }
}
