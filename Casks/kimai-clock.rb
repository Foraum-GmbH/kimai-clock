cask "kimai-clock" do
  version "1.0.0"
  sha256 "fccec797d1f964b845c24d7e74f4e9ea87972640db4a9d0ade0fd8bd2b45e088"

  url "https://github.com/Foraum-GmbH/kimai-clock/releases/download/v1.0.0/KimaiClock.dmg",
      verified: "github.com/Foraum-GmbH/kimai-clock/"
  name "KimaiClock"
  desc "KimaiClock is a lightweight macOS menu bar app that lets you track and manage Kimai 2 time entries directly from your desktop."
  homepage "https://github.com/Foraum-GmbH/kimai-clock"

  app "KimaiClock.app"
end
