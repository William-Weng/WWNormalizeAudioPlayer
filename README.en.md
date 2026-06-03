# WWNormalizeAudioPlayer

[![Swift-5.7](https://img.shields.io/badge/Swift-5.7-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![iOS-16.0](https://img.shields.io/badge/iOS-16.0-pink.svg?style=flat)](https://developer.apple.com/swift/)
![TAG](https://img.shields.io/github/v/tag/William-Weng/WWNormalizeAudioPlayer)
[![Swift Package Manager-SUCCESS](https://img.shields.io/badge/Swift_Package_Manager-SUCCESS-blue.svg?style=flat)](https://developer.apple.com/swift/)
[![LICENSE](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=flat)](https://developer.apple.com/swift/)

A normalized audio player that supports **sequential playback** and **volume normalization**, helping multiple audio tracks stay at a consistent loudness level.

[English](./README.en.md) | [繁體中文](./README.md)

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
    .package(url: "https://github.com/William-Weng/WWNormalizeAudioPlayer.git", .upToNextMajor(from: "1.5.0"))
]
```

---

## 🚀 Usage

### Play audio files from a Bundle

```swift
import WWNormalizeAudioPlayer

let player = WWNormalizeAudioPlayer()
let filenames = ["do-re-mi-re-do.m4a", "audio.mp3"]

Task {
    try audioPlayer.configure(delegate: self)
    await audioPlayer.play(filenames: filenames)
}
```

### Play from an array of URLs

```swift
let urls: [URL] = [
    Bundle.main.url(forResource: "do-re-mi-re-do", withExtension: "m4a")!,
    Bundle.main.url(forResource: "audio", withExtension: "mp3")!
]

Task {
    try audioPlayer.configure(delegate: self)
    await audioPlayer.play(filenames: filenames)
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
| `configure(delegate:preferredFrameRateRange:)` | Configures the delegate and update rate, then initializes the audio engine. |
| `play(at:filenames:targetDB:callbackType:loop:shuffle:)` | Play a list of audio files from a specific `Bundle`. |
| `play(with:targetDB:callbackType:loop:shuffle:)` | Play an array of audio URLs with sequential playback and volume normalization. |
| `totalTime()` | Calculate the total duration of all audio files in seconds. |
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

| Method | Description |
|---|---|
| `audioPlayer(_:trackIndex:currentTime:tracTime:)` | Called when playback progress updates. |
| `audioPlayer(_:didFinishTrackIndex:callbackType:)` | Called when a track finishes playing. |
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
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, error: Error) {
        print("error = \(error)")
    }
}
```
