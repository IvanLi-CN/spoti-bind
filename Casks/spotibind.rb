cask "spotibind" do
  version "0.2.7"
  sha256 "ce84009c0daa005864e88920c93541a153d0a6d4992a6582510f8ff60b7e1e5b"

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
