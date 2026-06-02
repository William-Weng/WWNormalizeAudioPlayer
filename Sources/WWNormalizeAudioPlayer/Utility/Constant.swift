//
//  Constant.swift
//  WWNormalizeAudioPlayer
//
//  Created by William Weng on 2026/2/16.
//

import Foundation

// MARK: - enum
public extension WWNormalizeAudioPlayer {
    
    /// WWNormalizeAudioPlayer 的自訂錯誤類型
    enum CustomError: Error {
        
        case currentTimeUnavailable             // 當前時間不可用（例如計時器未啟動或音頻尚未播放）
        case playerNodeNotReady                 // 播放器節點（playerNode）未就緒或不存在
        case audioSessionConfigurationFailed    // 音頻會話（audioSession）配置失敗
    }
}
    
