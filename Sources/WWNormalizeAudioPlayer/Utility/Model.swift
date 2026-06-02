//
//  Model.swift
//  WWNormalizeAudioPlayer
//
//  Created by iOS on 2026/6/2.
//

import Foundation

/// 單一頻譜 bar 的資料
public extension WWNormalizeAudioPlayer {
    
    struct SpectrumBar {
        
        public let index: Int                   // bar 的索引
        public let lowerFrequency: Float        // 這個 bar 對應的最低頻率
        public let upperFrequency: Float        // 這個 bar 對應的最高頻率
        public let amplitude: Float             // 正規化後的振幅，範圍為 0...1
    }
}
