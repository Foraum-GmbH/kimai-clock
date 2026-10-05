# KimaiClock

A native macOS menu bar app for Kimai 2 time tracking.

[![macOS](https://img.shields.io/badge/macOS-15%2B-1c1c1e?logo=apple&logoColor=white)](https://github.com/Foraum-GmbH/kimai-clock)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Kimai](https://img.shields.io/badge/Kimai-2.x-007acc)](https://www.kimai.org/)
[![Notarized](https://img.shields.io/badge/Apple-Notarized-success)](https://developer.apple.com/developer-id/)
[![License](https://img.shields.io/badge/License-MIT-gray)](./LICENSE.md)
[![Tests](https://img.shields.io/badge/Tests-105-success)](#testing)
[![Coverage](https://img.shields.io/badge/Coverage%20(logic)-77%25-success)](#testing)

![App Overview](https://github.com/Foraum-GmbH/kimai-clock/blob/main/assets/hero.jpeg?raw=true)

## Overview

KimaiClock brings your [Kimai](https://www.kimai.org/) time tracking into the macOS menu bar. Designed for speed and minimal disruption to your workflow, it allows you to start, pause, annotate, and switch timers without opening a browser window.

> [!NOTE]  
> KimaiClock requires Kimai 2. It does not support legacy Kimai 1 installations.

## Features

- **Menu Bar Control**: Start, pause, resume, and stop timesheets directly from the status item.
- **In-Place Descriptions**: Add or update timesheet notes on the fly without visiting the web interface.
- **Recent Activities**: Reopen and resume recent tasks with a single click.
- **Smart Idle Detection**: Detects system inactivity, prompts upon return, and retroactively adjusts logged duration.
- **App Launch Reminders**: Prompts you to start tracking when selected developer tools (VS Code, PhpStorm, Xcode) launch.
- **Automation Ready**: First-class URL schemes for macOS Shortcuts, Raycast, Alfred, and shell scripts.
- **Desktop Widget**: Native widget extension showing active timers and elapsed duration.
- **Native and Secure**: Built with Swift 6 and SwiftUI, zero external dependencies, sandboxed, and Apple-notarized.
- **Localization**: English and German interface support.

## Controls and Shortcuts

### Menu Bar Status Item

- **Left click**: Open or close the popover.
- **Left click and hold**: Open the Kimai web dashboard in your default browser.
- **Right click**: Toggle play/pause for the active task.

### Stop Button Context Menu

Right-clicking the stop button inside the popover reveals additional options:

| Action | Description |
|---|---|
| **Stop with description** | Prompts for a note, then stops and records the timesheet with that comment. |
| **Discard and delete** | Immediately cancels the timer and removes the timesheet from the server. |

### Idle Detection

KimaiClock monitors system idle time while an activity is running. When you return after reaching your configured idle threshold, a dialog lets you resolve the gap:

- **Continue without idle time**: Keep the timer running and deduct the absence from the timesheet.
- **Continue and keep idle time**: Keep the timer running and count the absence (e.g. a phone call).
- **Stop**: Stop and record the timesheet at the exact moment you stepped away.

Tick **Remember my choice** to apply the same option automatically next time; *Reset alerts* in Settings brings the dialog back. You can configure or disable the idle threshold in Settings.

When your Mac goes to sleep, the running timesheet is stopped at the moment of sleep, just like on quit or shutdown.

## Installation

### Homebrew (Recommended)

Install the cask via the official tap:

```bash
brew tap foraum-gmbh/foraum https://github.com/Foraum-GmbH/homebrew-foraum
brew install --cask foraum-gmbh/foraum/kimai-clock
```

To update or remove:

```bash
brew upgrade --cask kimai-clock
brew uninstall --cask kimai-clock
brew untap foraum-gmbh/foraum
```

### Direct Download

1. Download the latest `.dmg` release from the [Releases](../../releases) page.
2. Open the disk image and drag **KimaiClock.app** into your **Applications** folder.
3. Launch KimaiClock, open Settings from the popover, and enter your Kimai server URL and API token.

## URL Schemes and Automation

KimaiClock registers custom URL schemes to support system hotkeys and automated workflows:

| URL | Description |
|---|---|
| `kimai-clock://startLast` | Starts the most recently tracked activity. |
| `kimai-clock://startLast?description=...` | Starts the most recent activity with an optional timesheet description. |
| `kimai-clock://pause` | Pauses the currently running timer. |
| `kimai-clock://stop` | Stops and commits the active timesheet. |

### Examples

**Terminal**
```bash
# Start the most recent activity with a note
open "kimai-clock://startLast?description=Reviewing%20pull%20requests"

# Pause the active timer
open "kimai-clock://pause"
```

**macOS Shortcuts**
1. Open the **Shortcuts** app and create a new shortcut.
2. Add the **Open URLs** action.
3. Enter the URL (such as `kimai-clock://startLast`).
4. Open the shortcut details panel and select **Add Keyboard Shortcut** (such as `Command + Shift + L`).

These URLs can also be triggered from launchers such as **Raycast**, **Alfred**, or **BetterTouchTool**.

## Widgets

KimaiClock includes a native widget extension for desktop and Notification Center placement, displaying your active activity and running duration at a glance.

## Testing

Unit tests live in `KimaiClockTests/` and run in CI on every push and pull request:

```bash
xcodebuild -project KimaiClock.xcodeproj -scheme KimaiClock -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO test
```

Coverage as of the last update (105 tests):

| Area | Coverage |
|---|---|
| Managers & models (`KimaiClock/Manager`) | 77% |
| `ApiManager` (Kimai REST API) | 90% |
| `AppDelegate` (idle, sleep, URL scheme handling) | 33% |
| App target overall, incl. SwiftUI views | 24% |

SwiftUI views are not unit tested. Behaviour that needs a real Mac, such as sleep, idle detection and the menu bar, is tested manually before each release.

## Changelog

For a detailed list of changes, bug fixes, and new features in each release, see [CHANGELOG.md](./CHANGELOG.md).

## Contributors

<a href="https://github.com/undeadd"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/u/8116188&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>
<a href="https://github.com/fabian-rohr"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/u/20979750&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>
<a href="https://github.com/dmytro-kerest"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/u/118644&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>
<a href="https://claude.ai"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/u/81847&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>

Contributions, issues, and feature requests are welcome. Feel free to check the [issues page](../../issues).

## License

Distributed under the MIT License. See [LICENSE](./LICENSE.md) for details.
