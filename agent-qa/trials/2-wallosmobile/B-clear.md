# Scenario: clear-keeps-sort
Why: e477e5d — "Clear filters" resets the filter but leaves the sort, and that state is also what persists.
Preconditions: logged in; a saved filter "Inactive" with sort "Name" is active on Subscriptions.
Package com.grappim.wallosmobile.debug, activity com.grappim.wallosmobile.MainActivity.
To force-stop (ONLY where a step says so): `adb shell am force-stop com.grappim.wallosmobile.debug`, then `adb shell am start -n com.grappim.wallosmobile.debug/com.grappim.wallosmobile.MainActivity`, then `sleep 4`.
The app opens on Dashboard; the drawer opens from the "Menu" button top-left.

Steps:
1. do: Launch the app, open the drawer, tap Subscriptions.
   expect: Only "Inactive" rows, alphabetical.
2. do: Tap "Filter", tap "Clear filters", close the sheet with Back.
   expect: Active and Inactive rows both show, still in alphabetical order.
3. do: Force-stop and relaunch, open the drawer, tap Subscriptions.
   expect: Active and Inactive rows both show, alphabetical. "Filter" shows "Name" selected and status "All".
