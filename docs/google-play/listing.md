# Google Play listing text

## App name
DoomWalk

## Short description (max 80)
Want to scroll? Earn it by taking a walk first.

## Full description (max 4000)
DoomWalk makes you walk before you can doomscroll.

It measures how far you scroll in your social and video apps, in actual metres, and only lets you scroll as far as you have walked. Run out, and those apps fade behind a blur until you get up and take a walk.

How it works
• Walking fills your bank of scrolling. Every day starts empty.
• Scrolling in apps like Instagram, TikTok, YouTube or Reddit spends it. Calls, maps, banking, messages and emergency apps are never touched.
• The more you scroll in a day, the more walking each metre costs.
• Bank empty? The app blurs and a card tells you how many steps unlock it. Taps still work.
• Three emergency passes a day unlock everything for five minutes.
• Choose Gentle, Balanced or Strict rules and set your own bank size.

Also included
• Today at a glance: steps, bank and what walking costs right now
• A week of walking, your streak and your most scrolled apps
• Your scrolling measured in giraffes, Eiffel Towers and Everests, with a card to share
• A notification and a home-screen widget

Private by design
No internet permission, no accounts, no ads, no tracking. Everything stays on your phone. DoomWalk uses Android's accessibility service only to measure scroll distance and see which app is open. It cannot read your screen.

## Accessibility API declaration (Play Console → App content)
Core functionality: DoomWalk measures vertical scroll distance in other apps and which app is in the foreground, so it can charge scrolling against steps the user walked and show a blur-and-unlock card over an app once the user's own scrolling allowance is used up. The service requests only typeViewScrolled and typeWindowStateChanged events, sets canRetrieveWindowContent to false and never reads screen content, text or user input. No accessibility data is collected, stored off-device or shared. The user enables the service themselves and can turn it off at any time in Settings → Accessibility.

## Foreground service declarations
- `health`: step counting while the user walks (requires ACTIVITY_RECOGNITION).
- `specialUse`: keeps the on-device scroll measuring and the bank notification running before activity permission is granted. Subtype text is in the manifest.

## Other permissions to justify
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: step counting and scroll measuring must keep running in the background; the user is asked and can decline. If Play rejects it, remove it from the manifest and the in-app step.
- `RECEIVE_BOOT_COMPLETED`: restart tracking after a reboot.

## Data safety form
Collects no data. Shares no data. Data is not transmitted off the device. Privacy policy URL: [doomwalk.lan.si/privacy](https://doomwalk.lan.si/privacy)

## Category / content rating
Health & Fitness. Everyone.
