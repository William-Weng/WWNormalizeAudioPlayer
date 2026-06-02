//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2026/2/10.
//

import UIKit
import AVFoundation
import WWNormalizeAudioPlayer

final class ViewController: UIViewController {
    
    private let audioPlayer = WWNormalizeAudioPlayer()
    private let filenames = ["do-re-mi-re-do.m4a", "audio.mp3"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task {
            try audioPlayer.configure(delegate: self)
            await audioPlayer.play(filenames: filenames)
        }
    }
}

extension ViewController: WWNormalizeAudioPlayer.Delegate {
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, trackIndex: Int, currentTime: TimeInterval, trackTime: TimeInterval) {
        
        let totalTime = player.totalTime()
        let audio = filenames[trackIndex]
        
        print("time (\(audio)) = \(currentTime) of \(trackTime) - \(totalTime)")
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, didFinishTrackIndex trackIndex: Int, callbackType: AVAudioPlayerNodeCompletionCallbackType) {
        let audio = filenames[trackIndex]
        print("finish = \(audio)")
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, error: any Error) {
        print("error = \(error.localizedDescription)")
    }
}

