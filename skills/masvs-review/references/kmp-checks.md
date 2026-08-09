# Static checks for a Compose Multiplatform client

Concrete checks for this stack: **Ktor, DataStore, Room, Compose, Koin, KMP source sets.**
Generic mobile security guidance assumes OkHttp/Retrofit/Volley on Android and
Alamofire/TrustKit on iOS, and most of its grep patterns find nothing here.

## Before anything: check every source set separately

A finding is per-platform. `commonMain` can be clean while an `androidMain` actual is not,
and an `expect` declaration tells you nothing about what its actuals do.

```bash
# where the platform-specific code is at all
find . -path ./build -prune -o -type d -name '*Main' -print | grep -vE 'commonMain|/build/'
# every actual of a security-relevant expect
grep -rn 'actual .*\(Cipher\|Storage\|TrustManager\|HttpClient\|Logger\)' --include=*.kt .
```

State the platform in every finding. "The app stores the token in plaintext" is wrong if
only the iOS actual does.

## MASVS-STORAGE

**The stored server credential is the asset.** Find where it lands, then find what protects it.

```bash
grep -rn 'stringPreferencesKey\|edit *{\|DataStore' --include=*.kt . | grep -v /build/
grep -rln 'Keystore\|SecretKey\|Cipher\.getInstance\|KeyGenParameterSpec' --include=*.kt .
```

- **DataStore is plaintext.** `Preferences` and `dataStore` files are readable on a rooted
  device and by anything with the app's uid. A credential there needs a Keystore-backed
  cipher over the value, or a documented reason it doesn't.
- **Room is plaintext too.** No SQLCipher by default. Usually fine for cached content;
  not fine if a row holds a credential or an auth-bearing URL.
- **`allowBackup`** — check the *release* manifest, not just debug. Grep both:

  ```bash
  grep -rn 'allowBackup\|dataExtractionRules\|fullBackupContent' --include=AndroidManifest.xml .
  ```

  `allowBackup="true"` with a stored credential means `adb backup` and cloud backup carry
  it off the device. A common inversion is `false` in the debug manifest and `true` in
  main — backwards, since debug is the build with nothing worth taking.
- **Logs.** The message lambda in a `logcat`-style facade defers construction but does not
  redact. Check both the call sites and whether the release build installs a backend at all:

  ```bash
  grep -rnE '(logcat|Timber|println|NSLog).{0,80}(token|apiKey|password|secret|cookie|Authorization)' --include=*.kt .
  ```

- **iOS**: is the credential in the Keychain, or in `NSUserDefaults`/a DataStore file?
  Check `kSecAttrAccessible*` — `WhenUnlocked` vs `Always` is the finding.

## MASVS-CRYPTO

- A key in source, in a build config field, or in the version catalogue is the finding.
  A key derived at first run and held in the Keystore is not.
- `KeyGenParameterSpec` — check the purposes, the block mode, and whether an IV is reused
  across encryptions. A fixed IV with AES-GCM is a real break, not a style point.
- **Don't grade platform TLS here.** That's MASVS-NETWORK.

## MASVS-NETWORK

```bash
grep -rn 'usesCleartextTraffic\|networkSecurityConfig' --include=AndroidManifest.xml .
grep -rln 'X509TrustManager\|HostnameVerifier\|checkServerTrusted\|SSLContext' --include=*.kt .
grep -rn 'http://' --include=*.kt --include=*.xml . | grep -v /build/
```

- **Cleartext in a self-hosted client is usually deliberate**, because LAN instances speak
  plain HTTP. It is still worth one row in the register, and the useful question is what
  bounds it — is the credential sent over it? Is the user warned?
- **A custom `TrustManager` is the check that matters, and generic guidance gets it wrong.**
  "Overrides `checkServerTrusted`" is not itself the bug; an *empty* override is. For a
  self-signed-cert flow, read what the override actually does and answer three questions:
  1. Does it fall through to the platform default for normal certs, or replace it?
  2. Is the accepted set bounded to certs the user explicitly approved, or does it accept
     anything once a flag is set?
  3. Is the pin per-**certificate**, or per-host? Per-host means a regenerated cert on the
     same address is silently accepted — which is the failure trust-on-first-use is
     supposed to prevent. Partly answerable from source: find the trust-store lookup the
     override consults and check its key — `(host, fingerprint)` is per-cert, `host` alone
     is per-host. A unit test that pins one cert and asserts a second cert on the same host
     is rejected is as good as source gets. Only the live-handshake proof — regenerate the
     leaf, restart, confirm the app actually objects — needs a device.
- **`HostnameVerifier` returning true unconditionally** has no legitimate version. Finding.
- **Ktor specifics**: the engine differs per platform (OkHttp/CIO/Darwin), so TLS config
  is per-actual. A trust override wired into one engine and not another is a per-platform
  finding, and `expect fun createEngine()` hides it.

## MASVS-PLATFORM

```bash
grep -rn 'exported="true"' --include=AndroidManifest.xml .
grep -rn 'intent-filter' -A4 --include=AndroidManifest.xml . | grep -i 'scheme\|host'
grep -rln 'WebView\|javaScriptEnabled\|addJavascriptInterface\|loadUrl' --include=*.kt .
```

- **A third-party login in an embedded WebView fails RFC 8252** regardless of how the
  WebView is configured: the app can read what the user types into someone else's login
  page, and the user cannot see the address bar. The fix is a Custom Tab / `ASWebAuthenticationSession`.
  If an embedded WebView is kept deliberately, the register needs to say what bounds it —
  JS off, no JS bridge, navigation restricted to the expected origin, cookies not shared.
- **Scraping a credential by driving a web login** is the same shape: the app is handling
  the user's password directly. Bound it — is the password ever stored, and is the
  scraping page fixed to the configured host?
- **Compose and screenshots**: nothing sets `FLAG_SECURE` by default, so a screen showing
  a credential lands in the recents thumbnail. Applies to the login screen and any
  "reveal API key" UI.
- **Deep links**: an `exported="true"` activity with an `intent-filter` is callable by any
  app on the device. Check what it does with the extras before trusting them.

## MASVS-CODE

- **`minSdk`** is MASVS-CODE-1. A low floor is a reach decision, not an oversight — bound it.
- **MASVS-CODE-3 is usually the real gap.** Nothing in a plain Gradle setup checks the
  version catalogue against an advisory feed. Check for a scanner before assuming:

  ```bash
  grep -rn 'dependencyCheck\|osv\|snyk\|dependabot' --include=*.kts --include=*.yml --include=*.toml .
  ls .github/dependabot.yml 2>/dev/null
  ```

- **MASVS-CODE-4**: a server response is untrusted input even when the user owns the
  server. Check that the deserializer tolerates unknown and null fields, and that HTML or
  URLs from the server are escaped before rendering or before being followed.

## MASVS-PRIVACY

- Diff the declared permissions against what the code calls. A permission nothing uses is
  a finding with a one-line fix.
- **Build flavours differ here.** A Play flavour with crash reporting and an F-Droid
  flavour without are two different privacy postures; review the one that ships to each.
- **MASVS-PRIVACY-4**: can the user clear the stored credential *and* the cached data from
  inside the app? A disconnect action that clears the key but leaves a populated database
  lets the next account see the previous one's rows — a privacy finding with a functional
  bug attached.

## What source cannot answer

Put these in the register's third table rather than reporting them as passing:

| Check | Needs |
|---|---|
| The **merged** manifest that actually ships | `assembleRelease` + read `build/outputs/.../AndroidManifest.xml` |
| What a backup actually contains | a device, `adb backup` / `bmgr` |
| Credential in the recents thumbnail | a device and a screenshot |
| TLS behaviour on the wire, and whether trust can be bypassed | a proxy, or a throwaway TLS front for the server |
| Whether the cert pin is per-certificate | regenerate the leaf, restart, confirm it objects |
| What R8 left in the release APK | the APK, `apktool`/`jadx` |
| Keystore key properties as enforced by hardware | a device |
