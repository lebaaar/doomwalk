# DoomWalk privacy policy

Last updated: 2026-10-04

DoomWalk does not collect, store off-device, share or sell any data. The app has no internet permission, so nothing can leave your phone.

## What the app uses and why

- **Accessibility service:** measures how far you scroll in other apps and notices which app is open, so it can charge scrolling against the steps you walked and blur apps when the bank is empty. It is declared with `canRetrieveWindowContent="false"`: it cannot read what is on your screen, and it only receives scroll and app-switch events (scroll distances and the package name of the open app).
- **Physical activity (step counter):** counts your steps to fill the bank.
- **Notifications:** shows what is left in the bank and the emergency-pass button.
- **Battery optimisation exemption:** keeps step counting and scroll measuring running in the background.

## Where data lives

Everything (steps, scrolled distance per app, settings) is stored in the app's private storage on your device. It is excluded from cloud backups. Uninstalling the app, or *Settings → Privacy → Erase all data*, deletes it.

## Contact

Questions: open an issue at https://github.com/lebaaar/doomwalk/issues.
