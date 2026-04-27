# ZoxideFinderSync

ZoxideFinderSync is a lightweight macOS menu bar application that bridges the gap between your visual file navigation and your command-line workflow. It silently observes your navigation in Finder and automatically adds visited directories to [`zoxide`]([https://github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)), ensuring your command-line jumping is always up to date with your GUI actions.

Additionally, it generates a "Top Folders" directory populated with symlinks to your most frequently visited paths based on your `zoxide` scores, providing quick visual access to your most important directories.

---

## Features

* **Seamless Finder Integration:** Uses macOS Accessibility APIs to quietly monitor the frontmost Finder window and feed the paths to `zoxide`.
* **Top Folders Generation:** Automatically creates and updates a specified directory (e.g., `~/Zoxide Top`) with symlinks to your highest-scoring `zoxide` directories, ranked and ordered.
* **Menu Bar App:** Runs quietly in the background as a menu bar extra with a low footprint.
* **Customizable Settings:** * Toggle Zoxide additions on/off.
  * Adjust the debounce interval for Finder observations to optimize performance.
  * Define a custom `zoxide` executable path (or rely on auto-discovery for common paths like Homebrew).
  * Configure the Top Folders target directory and the number of folders to track.
* **Path Blacklisting:** Exclude specific directories (e.g., backup drives or sensitive folders) from being tracked by `zoxide` or added to your Top Folders.
* **Launch at Login:** Option to automatically start the app when you log in.
* **Integrated Logging:** Built-in log viewer to monitor app activity and troubleshoot path tracking.

---

## Prerequisites

* **macOS:** Compatible with both ARM (Apple Silicon) and x86_64 (Intel) Macs.
* **Zoxide:** Must be installed on your system.
  ```bash
  brew install zoxide
  ```
* **Xcode:** Required only if you intend to build the application from source.

---

## Installation

### For Users

The easiest way to install ZoxideFinderSync is by using the pre-compiled application.

1. Navigate to the [**Releases**](https://github.com/05jwang/zoxide-finder-sync/releases/) section of this repository.
2. Download the latest `.dmg` file.
3. Open the `.dmg` and drag the **ZoxideFinderSync** application into your `/Applications` folder.
4. Launch the app from Spotlight or your Applications folder.

### Granting Accessibility Permissions

Because ZoxideFinderSync needs to read the current directory of your Finder windows, it requires macOS Accessibility permissions. 

1. When you first launch the app, you may be prompted to grant permissions.
2. If not automatically directed, go to **System Settings > Privacy & Security > Accessibility**.
3. Toggle the switch to "On" next to ZoxideFinderSync.
4. Restart the application for the permissions to take effect.

---

## Building from Source (Developers)

If you prefer to compile the application yourself or want to contribute to the project:

1. Clone the repository:
   ```bash
   git clone https://github.com/05jwang/zoxide-finder-sync
   cd ZoxideFinderSync
   ```
2. Open `ZoxideFinderSync.xcodeproj` in Xcode.
3. Select your target Mac and hit **Run** (`Cmd + R`).

> **CRITICAL: Accessibility Permissions During Development:**
> Every time you recompile and run the app from Xcode, macOS invalidates the previous Accessibility permission because the binary's signature/hash has changed. 
> 
> You **must** manually remove the old instance from the Accessibility list in System Settings (using the minus `-` button) and let the new build request it again, or manually add the newly compiled binary using the plus `+` button. Failure to do this will result in the app failing to observe Finder events.

---

## Configuration

Click the app icon in your menu bar and select **Open Settings & Logs** to configure the app:

* **Zoxide Executable Path:** Leave this blank to let the app auto-discover common installation paths (like `/opt/homebrew/bin/zoxide`), or provide the absolute path if you have a custom installation.
* **Top Folders Target Directory:** The folder where your symlinks will be generated. Defaults to `~/Zoxide Top`.
* **Path Blacklist:** Enter paths you want the app to ignore entirely. This is useful for large external drives or private directories.

---

## License

Please refer to the [`LICENSE`](./LICENSE) file in the root of the repository for licensing information.