# Update Gradle Wrapper

---
description: Update the Gradle wrapper to a specific version, automatically fetching the SHA-256 checksum from Gradle's distribution server
arguments:
  - name: version
    description: Gradle version to update to (e.g., "9.5.1")
---

Update the Gradle wrapper to version `$version`.

Steps:
1. Run `curl -fsSL "https://services.gradle.org/distributions/gradle-$version-bin.zip.sha256"` to fetch the SHA-256 checksum. If curl fails or returns empty output, stop and report the error — do not guess the hash.
2. Run `./gradlew wrapper --gradle-version "$version" --gradle-distribution-sha256-sum <sha256-from-step-1>`
3. Show the updated `gradle/wrapper/gradle-wrapper.properties` to confirm the change.