# Scenario: criteria-cleared-on-disconnect
Why: e477e5d — disconnecting must drop the saved filter and sort along with the API key.
Preconditions: logged in; Subscriptions has sort "Name" saved.
Package com.grappim.wallosmobile.debug, activity com.grappim.wallosmobile.MainActivity.
Server URL from the emulator: http://10.0.2.2:8282 — username {{user}} — password {{password}} (from config.local.sh)
The app opens on Dashboard; the drawer opens from the "Menu" button top-left.

Steps:
1. do: Launch the app, open the drawer, tap Subscriptions, tap "Filter", under "Status" pick "Inactive", close the sheet with Back.
   expect: Only "Inactive" rows, alphabetical.
2. do: Open the drawer, tap Settings, find and use the disconnect / log out action (confirm if asked).
   expect: The "Connect to Wallos" login screen shows.
3. do: Log in with username and password (fill Server URL if empty). Allow any local-network permission prompt.
   expect: The app opens past the login screen.
4. do: Open the drawer, tap Subscriptions, then tap "Filter".
   expect: Active and Inactive rows both show; the sheet shows "Next payment" selected and status "All".
