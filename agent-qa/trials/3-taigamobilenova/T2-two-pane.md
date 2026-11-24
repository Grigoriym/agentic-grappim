# Scenario: tablet-issues-two-pane-bars
Why: Issues now shows list and detail side by side on wide windows. Two old bugs: (a) opening the user story from an issue's detail pane crashed the app; (b) after going back from that user story, the single shared top bar showed the list's "+" instead of the issue's "⋮", so the issue's menu was unreachable. Now each pane has its own top bar, and there are never more than two panes.
Device: tablet in LANDSCAPE. Package com.grappim.taigamobile.fdroid.debug, activity com.grappim.taigamobile.MainActivity. The app is logged in as admin to the local Taiga, project "main-project" selected.
If a screen shows "Retry" or "Connection error", tap Retry once (the emulator network can lag), then continue.
To rotate (ONLY where a step says so): portrait = `adb shell settings put system user_rotation 1`, landscape = `adb shell settings put system user_rotation 0`, then `sleep 4`.
Issue #3 "Issue 23vv" is already promoted to user story #18 (its detail shows a "#18 Issue 1" link). Issue #16 also exists.

Steps:
1. do: Tap "Issues" in the rail.
   expect: The issues list fills the left part of the screen with its own top bar ("Issues" title and a "+" button). The right part is empty (no issue selected). There is no ≡ icon in any top bar.
2. do: Tap issue "#3 Issue 23vv" in the list.
   expect: Issue #3 opens on the RIGHT while the list stays visible on the LEFT. The right pane has its own top bar: back arrow, title "Issue #3", "⋮" (content-desc "Issue options"). The left pane still shows "Issues" and "+".
3. do: Tap "#16 issue 12" in the left list.
   expect: The right pane switches to Issue #16; the list stays on the left.
4. do: Tap "#3 Issue 23vv" again, then in the right pane tap the "#18 Issue 1" link.
   expect: The app does not crash. User story #18 replaces the issue in the RIGHT pane (title "User story #18", "⋮" with content-desc "User Story options"); the issues list stays on the left. Never three panes.
5. do: Tap the back arrow in the right pane's top bar.
   expect: Issue #3 is back in the right pane with "Issue #3" and "⋮" in ITS bar; the left pane still shows "Issues" and "+".
6. do: Tap "⋮" (Issue options) in the right pane.
   expect: A menu opens with Copy link, Delete and Promote. Close it with Back (do NOT tap any item).
7. do: Tap "+" in the left pane's top bar, then press Back.
   expect: A create-issue screen opens; after Back the two panes with both top bars are shown again.
