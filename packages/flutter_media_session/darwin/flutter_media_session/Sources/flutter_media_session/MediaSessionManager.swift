import MediaPlayer
#if os(iOS)
import AVFoundation
import UIKit
#elseif os(macOS)
import AppKit
#endif

class MediaSessionManager: NSObject {
    private let sendEvent: (Any) -> Void
    private var commandTargets: [Any] = []
    private var durationMs: Int64?

    init(eventSink: @escaping (Any) -> Void) {
        self.sendEvent = eventSink
        super.init()
    }

    // MARK: - Activate / Deactivate

    func activate() {
        #if os(iOS)
        configureAudioSession()
        #endif

        let center = MPRemoteCommandCenter.shared()

        registerCommand(center.playCommand, action: "play")
        registerCommand(center.pauseCommand, action: "pause")
        registerCommand(center.nextTrackCommand, action: "skipToNext")
        registerCommand(center.previousTrackCommand, action: "skipToPrevious")
        registerCommand(center.stopCommand, action: "stop")
        registerCommand(center.skipBackwardCommand, action: "rewind")
        registerCommand(center.skipForwardCommand, action: "fastForward")
        registerCommand(center.changeShuffleModeCommand, action: "shuffle")
        registerCommand(center.changeRepeatModeCommand, action: "repeat")
        registerSeekCommand(center.changePlaybackPositionCommand)

        #if os(iOS)
        registerRouteChangeObserver()
        #endif
    }

    #if os(iOS)
    @discardableResult
    func configureAudioSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }
    #endif

    func deactivate() {
        let center = MPRemoteCommandCenter.shared()

        for target in commandTargets {
            center.playCommand.removeTarget(target)
            center.pauseCommand.removeTarget(target)
            center.nextTrackCommand.removeTarget(target)
            center.previousTrackCommand.removeTarget(target)
            center.stopCommand.removeTarget(target)
            center.skipBackwardCommand.removeTarget(target)
            center.skipForwardCommand.removeTarget(target)
            center.changeShuffleModeCommand.removeTarget(target)
            center.changeRepeatModeCommand.removeTarget(target)
            center.changePlaybackPositionCommand.removeTarget(target)
        }
        commandTargets.removeAll()

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        #if os(iOS)
        unregisterRouteChangeObserver()
        #endif
    }

    func setSkipIntervals(forwardSeconds: Int, backwardSeconds: Int) {
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: forwardSeconds)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: backwardSeconds)]
    }

    // MARK: - Metadata

    func updateMetadata(title: String?, artist: String?, album: String?, artworkUri: String?, durationMs: Int64?) {
        self.durationMs = durationMs

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()

        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPMediaItemPropertyAlbumTitle] = album
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        if let durationMs = durationMs, durationMs > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        if let artworkUri = artworkUri {
            loadArtwork(from: artworkUri)
        }
    }

    // MARK: - Playback State

    func updatePlaybackState(status: String, positionMs: Int64, speed: Double, repeatMode: Int, shuffleModeEnabled: Bool) {
        #if os(iOS)
        if status == "playing" {
            // Re-assert the audio session: it may be deactivated between
            // activate() and first playback by other plugins or the system.
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        #endif

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(positionMs) / 1000.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = status == "playing" ? speed : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = speed

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        let center = MPRemoteCommandCenter.shared()
        center.changeShuffleModeCommand.currentShuffleType = shuffleModeEnabled ? .items : .off

        let repeatType: MPRepeatType
        switch repeatMode {
        case 1:
            repeatType = .all
        case 2:
            repeatType = .one
        default:
            repeatType = .off
        }
        center.changeRepeatModeCommand.currentRepeatType = repeatType
    }

    // MARK: - Available Actions

    func updateAvailableActions(_ actions: [String]?) {
        let center = MPRemoteCommandCenter.shared()

        if let actions = actions {
            center.playCommand.isEnabled = actions.contains("play")
            center.pauseCommand.isEnabled = actions.contains("pause")
            center.nextTrackCommand.isEnabled = actions.contains("skipToNext")
            center.previousTrackCommand.isEnabled = actions.contains("skipToPrevious")
            center.stopCommand.isEnabled = actions.contains("stop")
            center.skipBackwardCommand.isEnabled = actions.contains("rewind")
            center.skipForwardCommand.isEnabled = actions.contains("fastForward")
            center.changeShuffleModeCommand.isEnabled = actions.contains("shuffle")
            center.changeRepeatModeCommand.isEnabled = actions.contains("repeat")
            center.changePlaybackPositionCommand.isEnabled = actions.contains("seekTo")
        } else {
            // nil = enable all
            center.playCommand.isEnabled = true
            center.pauseCommand.isEnabled = true
            center.nextTrackCommand.isEnabled = true
            center.previousTrackCommand.isEnabled = true
            center.stopCommand.isEnabled = true
            center.skipBackwardCommand.isEnabled = true
            center.skipForwardCommand.isEnabled = true
            center.changeShuffleModeCommand.isEnabled = true
            center.changeRepeatModeCommand.isEnabled = true
            center.changePlaybackPositionCommand.isEnabled = true
        }
    }

    // MARK: - Command Registration

    private func registerCommand(_ command: MPRemoteCommand, action: String) {
        command.isEnabled = true
        let target = command.addTarget { [weak self] _ in
            self?.sendEvent(action)
            return .success
        }
        commandTargets.append(target)
    }

    private func registerSeekCommand(_ command: MPRemoteCommand) {
        command.isEnabled = true
        let target = command.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let positionMs = Int64(positionEvent.positionTime * 1000)
            self?.sendEvent([
                "action": "seekTo",
                "args": positionMs
            ])
            return .success
        }
        commandTargets.append(target)
    }

    // MARK: - Artwork

    private func loadArtwork(from uri: String) {
        if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
            guard let url = URL(string: uri) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let data = data, error == nil else { return }
                self?.setArtworkFromData(data)
            }.resume()
        } else {
            // Local file path
            let path = uri.hasPrefix("file://") ? String(uri.dropFirst(7)) : uri
            let url = URL(fileURLWithPath: path)
            guard let data = try? Data(contentsOf: url) else { return }
            setArtworkFromData(data)
        }
    }

    private func setArtworkFromData(_ data: Data) {
        #if os(iOS)
        guard let image = UIImage(data: data) else { return }
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        #elseif os(macOS)
        guard let image = NSImage(data: data) else { return }
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        #endif

        DispatchQueue.main.async {
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    // MARK: - Route Change (iOS only)

    #if os(iOS)
    private func registerRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    private func unregisterRouteChangeObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        if reason == .oldDeviceUnavailable {
            sendEvent("pause")
        }
    }
    #endif
}
