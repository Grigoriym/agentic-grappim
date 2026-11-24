# Scenario: phone-drawer-unchanged
Why: phones must be unchanged by the tablet work, and a phone in LANDSCAPE (wide but short) must keep the slide-out drawer instead of getting a rail or a bottom bar with 12 items.
Device: phone. Package com.grappim.taigamobile.fdroid.debug, activity com.grappim.taigamobile.MainActivity. The app is logged in as admin to the local Taiga, project "main-project" selected.
If a screen shows "Retry" or "Connection error", tap Retry once (the emulator network can lag), then continue.
To rotate (ONLY where a step says so): portrait = `adb shell settings put system user_rotation 0`, landscape = `adb shell settings put system user_rotation 1`, then `sleep 4`.

Steps:
1. do: In portrait, look at the Dashboard.
   expect: A top bar with a ≡ (content-desc "Menu") on the left; no rail and no bottom navigation bar.
2. do: Tap ≡, then tap "Issues" in the drawer.
   expect: The drawer closes and the issues list fills the screen with one top bar: ≡, "Issues", "+".
3. do: Tap "#3 Issue 23vv", then press Back.
   expect: The issue fills the screen (back arrow, "Issue #3", "⋮"); Back returns to the list.
4. do: Rotate to landscape.
   expect: Still a top bar with ≡ and no rail or bottom bar. Tapping ≡ opens the slide-out drawer (close it again with Back).
5. do: Rotate back to portrait.
   expect: Same screen in portrait; no crash.
