[English](./README.en.md) | [繁體中文](./README.md)

# [WWNormalizeAudioPlayer](https://swiftpackageindex.com/William-Weng)

[![Swift-5.10](https://img.shields.io/badge/Swift-5.10-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![iOS-17.0](https://img.shields.io/badge/iOS-17.0-pink.svg?style=flat)](https://developer.apple.com/swift/)
![TAG](https://img.shields.io/github/v/tag/William-Weng/WWNormalizeAudioPlayer)
[![Swift Package Manager-SUCCESS](https://img.shields.io/badge/Swift_Package_Manager-SUCCESS-blue.svg?style=flat)](https://developer.apple.com/swift/)
[![LICENSE](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=flat)](https://developer.apple.com/swift/)

A normalized audio player that supports **sequential playback** and **volume normalization**, helping multiple audio tracks stay at a consistent loudness level.

---

## 📖 Introduction

`WWNormalizeAudioPlayer` plays a list of audio files and can adjust playback gain according to a target dB value.
It is useful when you want to play multiple audio tracks in sequence without sudden volume jumps between sources.

---

## ✨ Features

- Play audio files directly from a `Bundle` by filename.
- Play audio from an array of `URL`s.
- Support sequential playback of multiple tracks.
- Support volume normalization with a configurable `targetDB`.
- Provide playback progress callbacks, track-finished callbacks, and error reporting.
- Support pause, resume, and stop actions.

---

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/William-Weng/WWNormalizeAudioPlayer.git", .upToNextMajor(from: "1.6.0"))
]
```

---

## 🚀 Usage

```swift
iimport UIKit
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
```

---

## ⚙️ Available Properties

| Property | Description |
|---|---|
| `equalizer` | Audio equalizer wrapper. |
| `volume` | Adjusts the player volume, ranging from `0.0 ~ 1.0`. |
| `audioNode` | The node representing the currently playing audio, suitable for installing a tap to capture real-time audio data. |

---

## 🧩 Available Methods

| Method | Description |
|---|---|
| `prepare(audioURLs:delegate:preferredFrameRateRange:options:)` | Configures the delegate and update rate, then initializes the audio engine. |
| `play(at:filenames:targetDB:)` | Play one of the tracks from the audio file list. |
| `stop()` | Stop playback and reset the player state. |
| `resume()` | Resume playback from the paused position. |
| `pause()` | Pause playback while keeping the current position. |

---

## ⚠️ Error Types

| Error | Description |
|---|---|
| `currentTimeUnavailable` | The current playback time is unavailable. |
| `playerNodeNotReady` | The player node is not ready. |
| `audioSessionConfigurationFailed` | Audio session configuration failed. |

---

## 📝 Delegate

## 📝 WWNormalizeAudioPlayer.Delegate

| Method | Description |
|---|---|
| `audioPlayer(_:prepare:)` | Notifies the delegate that the player is about to prepare the specified tracks. |
| `audioPlayer(_:isPlaying:currentTime:tracTime:)` | Reports the current playback progress. |
| `audioPlayer(_:didFinished:)` | Notifies the delegate that the current track has finished playing. |
| `audioPlayer(_:error:)` | Called when an error occurs during playback. |

---

## 💡 Example

```swift
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
```
