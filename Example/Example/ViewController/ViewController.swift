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
    
    private let normalizeAudioPlayer = WWNormalizeAudioPlayer()
    private let url = Bundle.main.url(forResource: "audio", withExtension: "mp3")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        normalizeAudioPlayer.delegate = self
        normalizeAudioPlayer.play(with: url)
    }
}

extension ViewController: WWNormalizeAudioPlayer.Deleagte {
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, error: any Error) {
        print(error)
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, didFinishPlaying audioFile: AVAudioFile) {
        print(audioFile)
    }
}

