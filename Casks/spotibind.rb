cask "spotibind" do
  version "0.2.6"
  sha256 "84bbca994079472528d4088a2b456deec6dd7b33d470993ff381c408385b360c"

  url "https://github.com/IvanLi-CN/spoti-bind/releases/download/v#{version}/SpotiBind-#{version}-universal.dmg"
  name "SpotiBind"
  desc "Route media keys to the music player you choose"
  homepage "https://github.com/IvanLi-CN/spoti-bind"

  depends_on macos: :ventura

  app "SpotiBind.app"

  caveats do
    <<~EOS
      SpotiBind is Ad Hoc signed and not notarized. If macOS blocks the first
      launch, open SpotiBind.app from Finder with Control-click, then Open.
      Accessibility permission is required for media-key forwarding.
    EOS
  end
end
