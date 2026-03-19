# KimaiClock

![Swift](https://img.shields.io/badge/Swift-5.0-brightgreen?logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-15+-brightgreen?logo=apple&logoColor=white)
![Notarized](https://img.shields.io/badge/Notarized-Yes-brightgreen?logo=apple&logoColor=white)

![App Overview](https://github.com/Foraum-GmbH/kimai-clock/blob/main/assets/hero.jpeg?raw=true)

## 📖 About

KimaiClock is a macOS menu bar application that integrates with [Kimai](https://www.kimai.org/) to help you track your time directly from your desktop.

> [!WARNING]  
> This Version only works with Kimai 2 ( not the legacy Kimai 1 )

## ✨ Features

- ⏱️ Start, pause & stop timesheets from the menu bar
- 📝 Stop with a description — add a note right from the menu bar without opening Kimai
- 📊 View and resume recent tasks
- 🔔 App launch reminders (VS Code, PhpStorm, Xcode, …)
- 📡 Automatically sync timesheets with Kimai server
- 📥 Controllable via URL schemes (custom hotkeys via macOS Shortcuts, Alfred, Raycast, …)
- 📓 English & German localization
- 🔒 Secure, Apple-notarized build
- ⚡ Lightweight — no third-party dependencies
- 🌑 Dark mode support
- 📨 Actively maintained

## 📋 Changelog

For a detailed list of changes, bug fixes, and new features in each release, see [CHANGELOG.md](./CHANGELOG.md).

## 🎛️ Menu Bar Button Actions

- **Left click** → Open/close the popup
- **Left long press** → Open your Kimai server page in the default browser
- **Right click** → Toggle play/pause for the active task

## ✋ Stop Button Context Menu

Right-clicking the stop button inside the popup opens a context menu with two additional actions:

| Action | Description |
|--------|-------------|
| **Stop with description** | Opens a prompt to enter a note, then stops and saves the timesheet with that description |
| **Discard & delete** | Stops the timer and deletes the timesheet entirely — useful when started by accident |

## 🌙 Idle Detection

KimaiClock detects when your Mac has been idle for a configurable period while a timer is running. When you return, an alert lets you decide what to do:

- **Continue** — resume the timer as if nothing happened
- **Stop** — stop and save the timesheet up to the point you went idle

The idle threshold can be configured in Settings. A **"Don't show again"** checkbox is available if you prefer to manage this manually.

## 🚀 Installation

1. Go to the [Releases page](../../releases).  
2. Download the latest `.dmg` file.  
3. Open it and drag **KimaiClock.app** to your `Applications` folder.  
4. Connect your Kimai Server inside the Settings
5. Start tracking time right away 🚀

> [!TIP]  
> KimaiClock can also be installed via our own Homebrew tap right now:
>
> ```bash
> # add company tap
> brew tap foraum-gmbh/foraum https://github.com/Foraum-GmbH/homebrew-foraum
>
> # install cask from company tap
> brew install --cask foraum-gmbh/foraum/kimai-clock
> ```
>
> To uninstall KimaiClock and remove the company tap:
>
> ```bash
> # uninstall the app
> brew uninstall --cask foraum-gmbh/foraum/kimai-clock
>
> # remove the company tap
> brew untap foraum-gmbh/foraum
> ```
>
> 
> Once KimaiClock becomes more popular, we plan to submit it to the official Homebrew Cask repository.
>
> **Minimum requirements for official Homebrew Cask inclusion:**  
> - At least 30 forks  
> - At least 30 watchers  
> - At least 75 stars on GitHub

## 🔗 URL Schemes & Keyboard Shortcuts

KimaiClock supports URL schemes for automation and custom hotkey integration:

| Action | URL | Description |
|--------|-----|-------------|
| **Pause** | `kimai-clock://pause` | Pause the currently running timer |
| **Stop** | `kimai-clock://stop` | Stop and clear the active timer |
| **Start Last** | `kimai-clock://startLast` | Start the most recent activity |

### Usage Examples

**Terminal:**
```bash
open "kimai-clock://pause"
```

**macOS Shortcuts:**
1. Create a new Shortcut
2. Add the **"Open URLs"** action
3. Enter the url ( e.g. `kimai-clock://startLast` )
4. Click the **ⓘ** icon in the top-right
5. Select **"Add Keyboard Shortcut"** (e.g. `⌘⇧L`)

The URL schemes also work with third-party automation tools like **Alfred**, **Raycast**, or **BetterTouchTool**.

## 🖼️ Widgets

> [!WARNING]
> Widget support is currently work in progress and may have limited functionality.

A desktop widget is in development that will show the current timer state and elapsed time directly on your desktop or in the menu bar notification area. Available as a lock screen and home screen widget on supported macOS versions.



## 🤝 Contributors
<a href="https://github.com/fabian-rohr"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/u/20979750&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>
<a href="https://github.com/undeadd"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/u/8116188&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>
<a href="https://claude.ai"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/anthropics&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>

Contributions, issues and feature requests are welcome!  
Feel free to check the [issues page](../../issues).  

## 📜 License

Distributed under the MIT License.  
See [LICENSE](./LICENSE.md) for more information.
