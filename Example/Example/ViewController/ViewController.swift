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
    private let spectrumAnalyzer = WWNormalizeAudioPlayer.SpectrumAnalyzer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task {
            do {
                try audioPlayer.configure(delegate: self)

                let sampleRate = audioPlayer.audioNode.outputFormat(forBus: 0).sampleRate
                
                spectrumAnalyzer.installTap(on: audioPlayer.audioNode, sampleRate: sampleRate) { bars in
                    print(bars)
                }

                await audioPlayer.play(filenames: filenames)
            } catch {
                print(error)
            }
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

