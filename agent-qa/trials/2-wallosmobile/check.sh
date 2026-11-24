#!/bin/bash
# prints the stored subscriptions_criteria JSON, or ABSENT
v=$(adb -s emulator-5554 shell run-as com.grappim.wallosmobile.debug cat files/datastore/wallos_storage.preferences_pb | strings | grep -A1 '^subscriptions_criteria$' | tail -1)
echo "${v:-ABSENT}"
