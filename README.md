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

- ⏱️ Start & stop timesheets from the menu bar  
- 📊 View and resume recent tasks  
- 🔔 Idle detection reminders  
- 🔔 App launch reminders (VS Code, PhpStorm, Xcode, …)  
- 📡 Automatically sync timesheets with Kimai server
- 📓 English & German localization  
- 🔒 Secure, Apple-notarized build  
- ⚡ Lightweight & fast
- 📦 No third party dependency
- 🌙 Dark mode support  
- 📨 Actively maintained

## 🎛️ Menu Bar Button Actions

- **Left click** → Open/close the view  
- **Left long press** → Open your Kimai server page in the default browser  
- **Right click** → Toggle play/pause for the active task

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

## 🤝 Contributors
<a href="https://github.com/fabian-rohr"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/u/20979750&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>
<a href="https://github.com/undeadd"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/u/8116188&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>
<a href="https://github.com/dependabot"><img src="https://images.weserv.nl/?url=avatars.githubusercontent.com/u/27347476?s=200&w=300&h=300&fit=cover&mask=circle" width="50" height="50" style="border-radius:50%"/></a>

Contributions, issues and feature requests are welcome!  
Feel free to check the [issues page](../../issues).  

## 📜 License

Distributed under the MIT License.  
See [LICENSE](LICENSE) for more information.
