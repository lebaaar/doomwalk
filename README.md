<p align="center">
  <img src="docs/logo/final/png/icon-rounded-512.png" width="128" alt="DoomWalk icon">
</p>

<h1 align="center">DoomWalk</h1>

<p align="center"><b>Want to scroll? Earn it by taking a walk first.</b></p>

<p align="center">For Android · everything stays on your phone · no accounts, no ads, no tracking</p>

---

DoomWalk makes you walk before you can doomscroll. It measures how far you scroll in
your social and video apps, in real **metres**, and only lets you scroll as far as
you've walked. Run out, and those apps are **blocked** until you get up and take a walk.

<p align="center">
  <img src="docs/screenshots/host_intro_0.png" width="220" alt="Intro stories: want to scroll? Take a walk first">
  <img src="docs/screenshots/host_readme_today.png" width="220" alt="Today: steps, and the bank they filled">
  <img src="docs/screenshots/host_readme_activity.png" width="220" alt="Activity: a week of walking and scrolling by app">
</p>

## How it works

1. **Walking fills a small bank.** Every day starts with **0 m** in it (it empties at
   midnight), and it can hold **up to 50 m** of scrolling. Walking while it's full adds
   nothing, so walk when you want to scroll.
2. **Scrolling spends it.** Instagram, TikTok, YouTube, Reddit and the like count.
   Calls, maps, banking, messages and emergency apps are never touched.
3. **Scrolling gets more expensive.** Every metre of scrolling costs 3 m of walking
   to start with, and it goes up a tier for every 75 m you scroll in a day:

   | Scrolled today | Walking per metre | Filling the 50 m bank |
   |---|---|---|
   | 0–74 m | 3× | 200 steps |
   | 75–149 m | 5× | 334 steps |
   | 150–224 m | 7× | 467 steps |
   | 225–299 m | 10× | 667 steps |
   | 300 m and more | 15× (max) | 1,000 steps |

4. **Bank empty? The app is blocked.** It fades behind a blur with a card that says
   how many steps get you going again. Taps still work, it's just no fun.
5. **Emergencies happen.** Three passes a day unlock everything for five minutes.
6. **Every midnight is a fresh start.** The bank empties and prices go back down.

Prefer it gentler or stricter? Pick **Gentle**, **Balanced** or **Strict** in Settings,
and set the bank anywhere from 20 to 100 m.

## Features

* **Today at a glance:** your steps, how full the bank is, and what walking costs now.
* **A story-style intro** that explains it all in a minute, any time from Settings.
* **Activity:** steps against your daily goal (10,000 by default), a week of walking,
  your streak, and which apps you scroll most.
* **Landmarks:** your scrolling measured in giraffes, Eiffel Towers and Everests, with
  a card to share (`#DoomWalk`).
* **A notification** with what's left in the bank and an emergency-pass button, and
  **a home-screen widget** with the bank or the steps you need.
* **Light and dark mode.**

## Privacy

DoomWalk has **no internet permission**: nothing ever leaves your phone. It needs
Android's accessibility access to notice scrolling, but it can only see **how far** you
scroll and **which app** is open, never what's on the screen. Your data is not included
in cloud backups.

## Getting it

DoomWalk isn't in an app store yet. To build and install it yourself, see
[CONTRIBUTING.md](CONTRIBUTING.md).

**Why "DoomWalk"?** Doomscrolling plus a walk: the walk is the ticket, the scroll is
the ride. It's written **DoomWalk**, one word with a capital W.
