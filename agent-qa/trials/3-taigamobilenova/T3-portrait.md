# Scenario: tablet-portrait-single-pane
Why: in portrait (800dp wide) the tablet shows one screen at a time with the collapsed rail; the per-pane top bars must not appear there, and rotating with an issue open must keep it.
Device: tablet. Package com.grappim.taigamobile.fdroid.debug, activity com.grappim.taigamobile.MainActivity. The app is logged in as admin to the local Taiga, project "main-project" selected.
If a screen shows "Retry" or "Connection error", tap Retry once (the emulator network can lag), then continue.
To rotate (ONLY where a step says so): portrait = `adb shell settings put system user_rotation 1`, landscape = `adb shell settings put system user_rotation 0`, then `sleep 4`.

Steps:
1. do: Rotate to portrait. Tap "Issues" in the rail.
   expect: One screen only: the issues list with ONE top bar ("Issues", "+"), no ≡ icon in the top bar; the collapsed rail is on the left.
2. do: Tap "#3 Issue 23vv".
   expect: The issue fills the screen (no list next to it) with one top bar: back arrow, "Issue #3", "⋮".
3. do: Rotate to landscape.
   expect: Two panes: issues list on the left with "Issues" and "+", Issue #3 on the right with its back arrow and "⋮".
4. do: Rotate to portrait again.
   expect: Issue #3 alone with its back arrow and "⋮" (the open issue is kept).
5. do: Press the system Back key.
   expect: The issues list with "Issues" and "+".
6. do: Rotate back to landscape (leave the device in landscape).
   expect: The issues list with an empty right side; no crash.
