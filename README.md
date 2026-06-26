# WWNormalizeAudioPlayer

[![Swift-5.7](https://img.shields.io/badge/Swift-5.7-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![iOS-16.0](https://img.shields.io/badge/iOS-16.0-pink.svg?style=flat)](https://developer.apple.com/swift/)
![TAG](https://img.shields.io/github/v/tag/William-Weng/WWNormalizeAudioPlayer)
[![Swift Package Manager-SUCCESS](https://img.shields.io/badge/Swift_Package_Manager-SUCCESS-blue.svg?style=flat)](https://developer.apple.com/swift/)
[![LICENSE](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=flat)](https://developer.apple.com/swift/)

一個支援 **音量正規化** 與 **順序播放** 的音訊播放器，可讓多個音檔在播放時維持較一致的音量表現。

[English](./README.en.md) | [繁體中文](./README.md)

---

## 📖 簡介

`WWNormalizeAudioPlayer` 可用來播放一組音訊檔，並在需要時根據目標分貝值進行音量調整。
它適合用在需要連續播放多段音檔，或希望避免不同來源音檔音量忽大忽小的情境。

---

## ✨ 特色

- 支援從 `Bundle` 以檔名直接播放音檔。
- 支援 `URL` 陣列播放。
- 支援多段音檔依序播放。
- 支援音量正規化，可指定 `targetDB`。
- 支援播放進度通知、單曲播放完成通知與錯誤回報。
- 支援暫停、恢復與停止播放。

---

## 📦 安裝方式

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/William-Weng/WWNormalizeAudioPlayer.git", .upToNextMajor(from: "1.5.4"))
]
```

---

## 🚀 使用方式

### 直接播放 Bundle 內音檔

```swift
import WWNormalizeAudioPlayer

let player = WWNormalizeAudioPlayer()
let filenames = ["do-re-mi-re-do.m4a", "audio.mp3"]

Task {
    try audioPlayer.configure(delegate: self)
    await audioPlayer.play(filenames: filenames)
}
```

### 播放 URL 陣列

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

## ⚙️ 可用參數

| 參數 | 說明 |
|---|---|
| `equalizer` | 音訊等化器封裝。 |
| `volume` | 調整播放器音量，範圍為 `0.0 ~ 1.0`。 |
| `audioNode` | 目前播放音訊所對應的節點，可用於安裝 tap 取得即時音訊資料。 |
| `isLoop` | 循環播放開關。 |

---

## 🧩 可用方法

| 方法 | 說明 |
|---|---|
| `configure(delegate:preferredFrameRateRange:options:)` | 設定代理與更新頻率，並初始化音訊引擎。 |
| `play(at:filenames:targetDB:callbackType:loop:shuffle:)` | 播放指定 `Bundle` 中的音訊檔案列表。 |
| `play(with:targetDB:callbackType:loop:shuffle:)` | 播放音訊 URL 陣列，支援順序播放與音量正規化。 |
| `stop()` | 停止播放並重置狀態。 |
| `resume()` | 從暫停狀態繼續播放。 |
| `pause()` | 暫停播放並保留目前進度。 |

---

## ⚠️ 錯誤類型

| 錯誤 | 說明 |
|---|---|
| `currentTimeUnavailable` | 目前時間無法取得。 |
| `playerNodeNotReady` | 播放節點尚未準備好。 |
| `audioSessionConfigurationFailed` | 音訊 Session 設定失敗。 |

---

## 📝 Delegate

| 方法 | 說明 |
|---|---|
| `audioPlayer(_:trackIndex:didStartTracks:totalDuration:)` | 當音訊播放器開始播放一組音軌時呼叫。 |
| `audioPlayer(_:trackIndex:currentTime:tracTime:)` | 音訊播放進度更新時呼叫。 |
| `audioPlayer(_:didFinishTrackIndex:callbackType:)` | 單一軌道播放完成時呼叫。 |
| `audioPlayer(_:error:)` | 播放過程發生錯誤時呼叫。 |

---

## 💡 範例

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
```
