# Scenario: tablet-rail-collapse-expand
Why: on wide windows the navigation rail used to list all 12 destinations with no scrolling, so the last ones (Settings) were cut off and unreachable on short windows. Now it is Material's expandable rail: 7 main destinations when collapsed, all of them when expanded, scrollable.
Device: tablet in LANDSCAPE (1280x800dp). Package com.grappim.taigamobile.fdroid.debug, activity com.grappim.taigamobile.MainActivity. The app is logged in as admin to the local Taiga, project "main-project" selected.
If a screen shows "Retry" or "Connection error", tap Retry once (the emulator network can lag), then continue.
To rotate (ONLY where a step says so): portrait = `adb shell settings put system user_rotation 1`, landscape = `adb shell settings put system user_rotation 0`, then `sleep 4`.

Steps:
1. do: Launch the app; it opens on the Dashboard ("Board"). Look at the left side and the top bar.
   expect: A narrow rail on the left with a ≡ button at its top (content-desc "Expand navigation") and exactly these 7 items: Select Project, Board, Epics, Issues, Kanban, Backlog, Settings. No Team, Bookmarks, All Pages, Open Sprints or Closed Sprints. The top bar shows "Dashboard" and has NO ≡/Menu icon of its own.
2. do: Tap "Expand navigation".
   expect: The rail widens and shows labels next to icons; it now also lists Team, Bookmarks, All Pages, Open Sprints and Closed Sprints (12 items in total, some possibly below the fold). The button's content-desc is now "Collapse navigation".
3. do: In the expanded rail, scroll down inside the rail until Settings is visible, then tap Settings.
   expect: Settings is reachable by scrolling the rail and the Settings screen opens.
4. do: Expand the rail if it is collapsed, tap "Open Sprints", then tap "Collapse navigation".
   expect: The Open Sprints screen opens. In the collapsed rail, "Open Sprints" is shown (selected) in addition to the 7 main items, because it is the current section.
