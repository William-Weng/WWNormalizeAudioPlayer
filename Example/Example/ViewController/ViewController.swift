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
    private let url = Bundle.main.url(forResource: "audio", withExtension: "mp3")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        audioPlayer.delegate = self
        audioPlayer.play(with: url)
    }
}

extension ViewController: WWNormalizeAudioPlayer.Deleagte {
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, callbackType: AVAudioPlayerNodeCompletionCallbackType, didFinishPlaying audioFile: AVAudioFile) {
        print(callbackType)
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, audioFile: AVAudioFile, totalTime: TimeInterval, currentTime: TimeInterval) {
        print(currentTime / totalTime)
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, error: any Error) {
        print(error)
    }
}

