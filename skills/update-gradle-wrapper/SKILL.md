---
name: update-gradle-wrapper
description: Updates the Gradle wrapper to a specific version, fetching the SHA-256
  checksum from Gradle's distribution server rather than guessing it. Use when the
  user asks to update, upgrade, or bump Gradle, or names a target Gradle version such
  as "update gradle to 9.5.1".
metadata:
  author: grappim
  keywords:
  - gradle wrapper
  - update gradle
  - upgrade gradle
  - gradle version
  - distributionSha256Sum
  - gradlew wrapper
---

Updates the Gradle wrapper to a target version, with the distribution checksum
pinned so the download is verified.

## Step 0. Target version

Take the version from the user's request (for example `9.5.1`). If none was given,
ask — do not assume "latest" and do not pick one yourself.

Read `gradle/wrapper/gradle-wrapper.properties` first to record the current version,
so the change can be reported and reverted if needed.

## Step 1. Fetch the checksum

```bash
curl -fsSL "https://services.gradle.org/distributions/gradle-<version>-bin.zip.sha256"
```

If curl fails or the output is empty, **stop and report the error**. Never guess,
reuse, or hand-write the hash — a wrong `distributionSha256Sum` breaks every build in
the project with an opaque verification failure.

An empty response usually means that version doesn't exist; re-check the version
string before retrying.

## Step 2. Run the wrapper task

```bash
./gradlew wrapper --gradle-version "<version>" --gradle-distribution-sha256-sum <sha256>
```

Run this **twice**. The first run rewrites `gradle-wrapper.properties`; the second
regenerates the wrapper scripts and `gradle-wrapper.jar` using the new version.

Never hand-edit `gradle-wrapper.properties` — the wrapper task is what keeps the
properties, the jar, and the scripts consistent.

## Step 3. Verify

1. `gradle/wrapper/gradle-wrapper.properties` shows the new `distributionUrl` and a
   `distributionSha256Sum`.
2. `./gradlew --version` reports the target version.

Show the updated `gradle-wrapper.properties` to confirm the change.

## Notes

- Gradle version changes carry compatibility constraints with AGP, the JDK, and
  Kotlin. If the project fails to sync afterwards, check AGP's compatibility table
  before assuming the wrapper update is at fault.
- The changed files — `gradle-wrapper.properties`, `gradle-wrapper.jar`, `gradlew`,
  and `gradlew.bat` — all belong in the same commit.
