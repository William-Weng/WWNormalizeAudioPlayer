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
    private let index = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task {
            let audioURLs = filenames.map { URL.documentsDirectory.appendingPathComponent($0) }
            audioPlayer.prepare(audioURLs: audioURLs, delegate: self)
            try await audioPlayer.play(at: index)
        }
    }
}

extension ViewController: WWNormalizeAudioPlayer.Delegate {
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, prepare tracks: [WWNormalizeAudioPlayer.TrackInformation]) {
        tracks.forEach { print($0) }
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, isPlaying currentTime: TimeInterval, trackTime: TimeInterval) {
        print("[\(filenames[index])] = \(currentTime) of \(trackTime)")
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, didFinished callbackType: AVAudioPlayerNodeCompletionCallbackType) {
        print("finished = \(callbackType)")
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, error: Error) {
        print("error = \(error)")
    }
}
