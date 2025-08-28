cask "kimai-clock" do
  version "1.0.2"
  sha256 "3c9338abc428f6f10cad1bcfa580b15d6f74a14fb1003482ddc6107e93e9a5cb"

  url "https://github.com/Foraum-GmbH/kimai-clock/releases/download/v1.0.2/KimaiClock.dmg",
      verified: "github.com/Foraum-GmbH/kimai-clock/"
  name "KimaiClock"
  desc "KimaiClock is a lightweight macOS menu bar app that lets you track and manage Kimai 2 time entries directly from your desktop."
  homepage "https://github.com/Foraum-GmbH/kimai-clock"

  app "KimaiClock.app"
end
