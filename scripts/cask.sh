#!/bin/sh
# Prints the Homebrew cask for a release. Usage: scripts/cask.sh <version> <sha256>
# The tap keeps the file as Casks/dell-monitor-console.rb in github.com/ashwingopalsamy/homebrew-tap.
set -eu
[ $# -eq 2 ] || { printf 'usage: scripts/cask.sh <version> <sha256>\n' >&2; exit 1; }
cat <<EOF
cask "dell-monitor-console" do
  version "$1"
  sha256 "$2"

  url "https://github.com/ashwingopalsamy/dell-monitor-console/releases/download/v#{version}/Dell-Monitor-Console-#{version}.dmg"
  name "Dell Monitor Console"
  desc "Menu bar app for the brightness of your displays"
  homepage "https://apps.ashwingopalsamy.in/dell-monitor-console/"

  depends_on macos: ">= :tahoe"

  app "Dell Monitor Console.app"

  zap trash: [
    "~/Library/Preferences/apps.ashwingopalsamy.dellmonitorconsole.plist",
  ]
end
EOF
