cask "spotibind" do
  version "0.2.4"
  sha256 "bf2aa0ede470f9b274ebcdc18840ba2f2796d2636f2bb5323fb46eeb626768da"

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
