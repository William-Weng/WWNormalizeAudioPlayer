# WWNormalizeAudioPlayer
[![Swift-5.7](https://img.shields.io/badge/Swift-5.7-orange.svg?style=flat)](https://developer.apple.com/swift/) [![iOS-15.0](https://img.shields.io/badge/iOS-15.0-pink.svg?style=flat)](https://developer.apple.com/swift/) ![TAG](https://img.shields.io/github/v/tag/William-Weng/WWNormalizeAudioPlayer) [![Swift Package Manager-SUCCESS](https://img.shields.io/badge/Swift_Package_Manager-SUCCESS-blue.svg?style=flat)](https://developer.apple.com/swift/) [![LICENSE](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=flat)](https://developer.apple.com/swift/)

### [Introduction - 簡介](https://swiftpackageindex.com/William-Weng)
- [Normalizing the volume of music files will prevent the volume from fluctuating.](https://www.youtube.com/watch?v=3LXUaMj01nU)
- [將音樂檔案的音量正規化，不會讓音量有忽大忽小的情況發生。](https://medium.com/blendvision/有關audio-normalization兩三事-下-c74f42ccc3f6)

### [Installation with Swift Package Manager](https://medium.com/彼得潘的-swift-ios-app-開發問題解答集/使用-spm-安裝第三方套件-xcode-11-新功能-2c4ffcf85b4b)
```bash
dependencies: [
    .package(url: "https://github.com/William-Weng/WWNormalizeAudioPlayer.git", .upToNextMajor(from: "1.1.5"))
]
```

### 可用變數 (Parameter)
|函式|功能|
|-|-|
|volume|調整音樂播放器音量 (0.0 ~ 1.0)|
|isHiddenProgress|隱藏進度顯示|

### 可用函式 (Function)
|函式|功能|
|-|-|
|play(with:targetDB:)|播放音樂|
|stop()|停止播放音樂|
|pause()|暫停播放（保留目前進度）|
|resume()|繼續播放（從暫停位置繼續）|
|setSession(category:isActive:)|設定AVAudioSession|

### 可用協定 (Deleagte)
|函式|功能|
|-|-|
|audioPlayer(_:callbackType:didFinishPlaying:)|音樂播放完成|
|audioPlayer(_:audioFile:totalTime:currentTime:)|音樂播放進度|
|audioPlayer(_:error)|播放相關錯誤|

### Example
```swift
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
```
