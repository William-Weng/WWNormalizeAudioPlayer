//
//  Constant.swift
//  WWNormalizeAudioPlayer
//
//  Created by William Weng on 2026/2/16.
//

import Foundation

// MARK: - enum
public extension WWNormalizeAudioPlayer {
    
    /// 播放器目前的播放狀態
    enum PlaybackState {
        case idle                               // 尚未開始播放、沒有有效內容，或已完成初始化但未進入播放流程
        case playing                            // 正在播放中
        case paused                             // 已暫停，保留目前播放位置，可呼叫 resume 繼續
        case stopped                            // 已停止，播放流程中斷並重置部分狀態
    }
    
    /// WWNormalizeAudioPlayer 的自訂錯誤類型
    enum CustomError: Error {
        case currentTimeUnavailable             // 當前時間不可用（例如計時器未啟動或音頻尚未播放）
        case playerNodeNotReady                 // 播放器節點（playerNode）未就緒或不存在
        case audioSessionConfigurationFailed    // 音頻會話（audioSession）配置失敗
    }
}
    
