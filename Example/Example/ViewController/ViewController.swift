//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2026/6/2.
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
            audioPlayer.configure(delegate: self)
            await audioPlayer.play(filenames: filenames)
        }
    }
}

extension ViewController: WWNormalizeAudioPlayer.Delegate {
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, didStartTracks tracks: [URL], totalDuration: TimeInterval) {
        tracks.forEach { print($0) }
        print("total = \(totalDuration) sec")
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, trackIndex: Int, currentTime: TimeInterval, trackTime: TimeInterval) {
        let audio = filenames[trackIndex]
        print("time (\(audio)) = \(currentTime) of \(trackTime)")
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, didFinishTrackIndex trackIndex: Int, callbackType: AVAudioPlayerNodeCompletionCallbackType) {
        let audio = filenames[trackIndex]
        print("finish = \(audio)")
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, error: Error) {
        print("error = \(error)")
    }
}
