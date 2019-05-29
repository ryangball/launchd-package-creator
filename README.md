# <p>launchd Package Creator <img alt="Icon" src="images/icon_32x32@2x.png"></p>
A utility that allows you to easily create a .pkg containing a LaunchDaemon or LaunchAgent, and a target script of your choosing. The target script is also packaged, so nothing else is required on the Mac the package is installed on.
<p align="center">
    <img alt="Main Window" width="586" src="images/main_window.png">
</p>

## Usage
1. Install the latest [release](https://github.com/ryangball/launchd-package-creator/releases/latest)
2. Select the launchd type (daemon/agent)
3. Input an indentifier (reverse domain name notation is typical)
4. Input a version
5. Select a target script/app (apps are allowed, but should be set to LimitLoadToSessionType: Aqua, which will be added in a future release)
6. Select your options (more to come)
7. Click the "Create PKG" button to create a package of the launchd item and target script/app
8. TEST

## Notes
- When creating a LaunchAgent (which runs as the user) **and** selecting the StandardOutPath and StandardErrorPath options, you should be mindful as to whether or not the user has access to write to the chosen path/file. Daemons might not have this limitation, as they are run as root (when using this utility).
- When targeting a GUI application (.app) it is recommended to use a LaunchAgent with LimitLoadToSessionType: Aqua. This will run as the user once they are logged in.
## Issues and Feature Requests
Please [create an issue](https://github.com/ryangball/launchd-package-creator/issues) for both issues encountered and for feature requests (like additional options that might be useful) or [create a PR](https://github.com/ryangball/launchd-package-creator/pulls).