//
//  Constant.swift
//  WWNormalizeAudioPlayer
//
//  Created by William Weng on 2026/2/16.
//

import Foundation

// MARK: - typealias
public extension WWNormalizeAudioPlayer {
    
    // 原始頻帶資料分析完成後的回呼型別
    typealias SpectrumRawBandsHandler = ([SpectrumBandRaw]) -> Void
}

// MARK: - enum
public extension WWNormalizeAudioPlayer {
    
    /// WWNormalizeAudioPlayer 的自訂錯誤類型
    enum CustomError: Error {
        case isEmptyFile                                            // 沒有任何檔案
        case currentIndexUnavailable                                // 目前曲目索引不可用（例如尚未載入音軌清單或索引無效）
        case currentTimeUnavailable                                 // 當前時間不可用（例如計時器未啟動或音頻尚未播放）
        case playerNodeNotReady                                     // 播放器節點（playerNode）未就緒或不存在
        case audioSessionConfigurationFailed                        // 音頻會話（audioSession）配置失敗
        case equalizerBandIndexOutOfRange(index: Int, count: Int)   // 等化器 band 索引超出範圍
    }
    
    /// 播放器目前的播放狀態
    enum PlaybackState {
        case idle                               // 尚未開始播放、沒有有效內容，或已完成初始化但未進入播放流程
        case playing                            // 正在播放中
        case paused                             // 已暫停，保留目前播放位置，可呼叫 resume 繼續
        case stopped                            // 已停止，播放流程中斷並重置部分狀態
    }
    
    /// 預設的等化器音色配置
    enum EqualizerPreset {
        case flat                               // 平坦模式，不特別強調任何頻段
        case bassBoost                          // 增強低頻，讓低音更有份量
        case bassCut                            // 減少低頻，讓聲音更乾淨、不那麼厚重
        case trebleBoost                        // 增強高頻，讓聲音更明亮、清晰
        case trebleCut                          // 減少高頻，讓聲音更柔和、不刺耳
        case vocalBoost                         // 增強人聲常見頻段，讓語音更突出
        case custom([Float])                    // 自訂每個 band 的增益值，陣列內容通常對應各頻段的 gain
    }
    
    /// 等化器單一頻段的濾波器類型
    enum EqualizerBandType {
        case parametric                         // 標準參數式等化器，最常用的類型
        case lowPass                            // 低通濾波，只保留低於指定頻率的訊號
        case highPass                           // 高通濾波，只保留高於指定頻率的訊號
        case resonantLowPass                    // 具共振特性的低通濾波
        case resonantHighPass                   // 具共振特性的高通濾波
        case bandPass                           // 通帶濾波，只保留指定頻段附近的訊號
        case bandStop                           // 阻帶濾波，抑制指定頻段附近的訊號
        case lowShelf                           // 低架式濾波，用來增減低頻整體能量
        case highShelf                          // 高架式濾波，用來增減高頻整體能量
        case resonantLowShelf                   // 具共振特性的低架式濾波
        case resonantHighShelf                  // 具共振特性的高架式濾波
    }
}

// MARK: - WWNormalizeAudioPlayer.CustomError
extension WWNormalizeAudioPlayer.CustomError: LocalizedError {
    
    public var errorDescription: String? {
        
        switch self {
        case .isEmptyFile: return "沒有任何聲音檔 (播放清單為空)"
        case .currentIndexUnavailable: return "目前曲目索引不可用（例如尚未載入音軌清單或索引無效）"
        case .currentTimeUnavailable: return "當前時間不可用（例如計時器未啟動或音頻尚未播放）"
        case .playerNodeNotReady: return "播放器節點（playerNode）未就緒或不存在"
        case .audioSessionConfigurationFailed: return "音頻會話（audioSession）配置失敗"
        case .equalizerBandIndexOutOfRange(let index, let count): return "等化器 band 索引超出範圍：\(index)，有效範圍為 0 到 \(max(count - 1, 0))"
        }
    }
}
