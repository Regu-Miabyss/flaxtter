Pod::Spec.new do |s|
  s.name             = 'flutter_media_session'
  s.version          = '0.0.1'
  s.summary          = 'Flutter Media Session plugin for iOS and macOS'
  s.description      = <<-DESC
Sync media metadata and playback state with system controls on iOS and macOS.
                       DESC
  s.homepage         = 'https://github.com/wyrindev/flutter-media-session'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'wyrindev' => 'wyrindev' }
  s.source           = { :path => '.' }

  s.source_files = 'flutter_media_session/Sources/flutter_media_session/**/*'

  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.15'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'

  s.ios.frameworks = 'MediaPlayer', 'AVFoundation'
  s.osx.frameworks = 'MediaPlayer'

  s.swift_version = '5.0'
end
