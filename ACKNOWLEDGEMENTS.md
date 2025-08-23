# Acknowledgements

We gratefully acknowledge the following open source projects that made this app way easier to build and maintain.  

---

## In-App Usage
These libraries are included in or directly used by the application:

- [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) (MIT License)  
  Used to optionally start the app automatically after login.  

---

## Build & CI/CD Tooling
These tools are used only during the build, packaging, or release process, and are not included in the distributed application:

- [create-dmg](https://github.com/sindresorhus/create-dmg) (MIT License)  
  For creating a polished DMG installer.  

- [actions/checkout](https://github.com/actions/checkout) (MIT License)  
  For checking out source code in GitHub Actions.  

- [maxim-lobanov/setup-xcode](https://github.com/maxim-lobanov/setup-xcode) (MIT License)  
  For selecting an Xcode version in GitHub Actions.  

- [softprops/action-gh-release](https://github.com/softprops/action-gh-release) (MIT License)  
  For uploading release assets to GitHub.
  
- [create-dmg](https://github.com/create-dmg/create-dmg)  
  Used to package the `.dmg` installer for macOS.

- [xcpretty](https://github.com/xcpretty/xcpretty)  
  Used to format and clean up `xcodebuild` output in CI builds.

- [GraphicsMagick](http://www.graphicsmagick.org/) & [ImageMagick](https://imagemagick.org/)  
  Used by `create-dmg` to handle app icon and image processing during build.  

---

🙏 Thanks to the authors and contributors of these projects for making their work available to the community.
