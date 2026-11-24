# Scenario: filter-sort-survive-relaunch
Why: e477e5d — the Subscriptions filter and sort used to reset on every fresh launch; now they must survive a force-stop.
Preconditions: app installed and logged in to Wallos; no filter or sort was ever saved.
Package com.grappim.wallosmobile.debug, activity com.grappim.wallosmobile.MainActivity.
To force-stop (ONLY where a step says so): `adb shell am force-stop com.grappim.wallosmobile.debug`, then `adb shell am start -n com.grappim.wallosmobile.debug/com.grappim.wallosmobile.MainActivity`, then `sleep 4`.
The app opens on Dashboard; the drawer opens from the "Menu" button top-left.

Steps:
1. do: Launch the app, open the drawer, tap Subscriptions.
   expect: The list shows both active rows and rows with an "Inactive" badge.
2. do: Tap "Filter" (top right). In the sheet, under "Sort by" pick "Name"; under "Status" pick "Inactive". Close the sheet with Back.
   expect: Only rows with the "Inactive" badge remain, in alphabetical order by name.
3. do: Force-stop and relaunch the app, then open the drawer and tap Subscriptions.
   expect: Still only "Inactive" rows, alphabetical. Opening "Filter" shows "Name" and "Inactive" selected. Close the sheet with Back.
4. do: Open the drawer, tap Dashboard, then open the drawer again and tap Subscriptions. Don't touch the filter. Then force-stop and relaunch, open the drawer and tap Subscriptions.
   expect: Still only "Inactive" rows, alphabetical.
