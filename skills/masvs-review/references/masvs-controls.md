# MASVS v2 controls

The 24 control statements, quoted from
[`OWASP_MASVS.yaml`](https://github.com/OWASP/owasp-masvs/blob/master/OWASP_MASVS.yaml).

> **Licensing — this file mixes two.**
> The text in every **Statement** column is quoted verbatim from MASVS, © OWASP
> Foundation, licensed [**CC BY-SA 4.0**](https://creativecommons.org/licenses/by-sa/4.0/).
> Everything else here — the *Reading it here* commentary, the structure, the MASTG
> lookup section — is ours and carries the repo's Apache-2.0 licence.
> If you copy the tables elsewhere, keep the attribution and the CC BY-SA notice on the
> quoted statements.

## Storage

| Control | Statement | Reading it here |
|---|---|---|
| MASVS-STORAGE-1 | The app securely stores sensitive data. | The stored server credential is the asset. Room caches of user data are secondary. |
| MASVS-STORAGE-2 | The app prevents leakage of sensitive data. | Backups, logs, clipboard, keyboard cache, screenshots. `allowBackup` lives here. |

## Cryptography

| Control | Statement | Reading it here |
|---|---|---|
| MASVS-CRYPTO-1 | The app employs current strong cryptography and uses it according to industry best practices. | Only applies where you do crypto yourself. Platform TLS is MASVS-NETWORK. |
| MASVS-CRYPTO-2 | The app performs key management according to industry best practices. | Keystore/Keychain-backed, not a key in source or in DataStore. |

## Authentication and Authorization

| Control | Statement | Reading it here |
|---|---|---|
| MASVS-AUTH-1 | The app uses secure authentication and authorization protocols and follows the relevant best practices. | Where the credential comes from and how it is sent. Third-party login in an embedded WebView fails RFC 8252. |
| MASVS-AUTH-2 | The app performs local authentication securely according to the platform best practices. | Only if there is an app lock / biometric gate. Usually N/A. |
| MASVS-AUTH-3 | The app secures sensitive operations with additional authentication. | Step-up auth. Rarely applies to a self-hosted client. |

## Network Communication

| Control | Statement | Reading it here |
|---|---|---|
| MASVS-NETWORK-1 | The app secures all network traffic according to the current best practices. | Cleartext, TLS config, and any custom `TrustManager` / `HostnameVerifier`. |
| MASVS-NETWORK-2 | The app performs identity pinning for all remote endpoints under the developer's control. | **Read the qualifier.** A user-supplied server is not under the developer's control, so this is N/A by construction — not a gap. Record it once. |

## Platform Interaction

| Control | Statement | Reading it here |
|---|---|---|
| MASVS-PLATFORM-1 | The app uses IPC mechanisms securely. | Exported components, deep links, content providers, implicit intents. |
| MASVS-PLATFORM-2 | The app uses WebViews securely. | JS enabled, `addJavascriptInterface`, mixed content, what the WebView is allowed to navigate to. |
| MASVS-PLATFORM-3 | The app uses the user interface securely. | Screenshot in recents, overlay/tapjacking, credentials visible in the UI. |

## Code Quality

| Control | Statement | Reading it here |
|---|---|---|
| MASVS-CODE-1 | The app requires an up-to-date platform version. | `minSdk`. A low floor is a deliberate reach decision — bound it in the register. |
| MASVS-CODE-2 | The app has a mechanism for enforcing app updates. | F-Droid / sideloaded builds have none. Usually an accepted deviation. |
| MASVS-CODE-3 | The app only uses software components without known vulnerabilities. | Is anything checking the dependency catalogue against an advisory feed? Usually nothing is. |
| MASVS-CODE-4 | The app validates and sanitizes all untrusted inputs. | Server responses are untrusted input, including from a server the user owns. |

## Resilience Against Reverse Engineering and Tampering

| Control | Statement | Reading it here |
|---|---|---|
| MASVS-RESILIENCE-1 | The app validates the integrity of the platform. | Root/jailbreak and emulator detection. |
| MASVS-RESILIENCE-2 | The app implements anti-tampering mechanisms. | Signature and integrity checks at runtime. |
| MASVS-RESILIENCE-3 | The app implements anti-static analysis mechanisms. | Obfuscation beyond what R8 does by default. |
| MASVS-RESILIENCE-4 | The app implements anti-dynamic analysis techniques. | Anti-debug, anti-hooking, Frida detection. |

**The whole category is normally out of scope for a self-hosted FOSS client.** It defends
a vendor's assets against the device owner; here the device owner *is* the data owner, and
the source is published anyway. Decide once, in the register.

## Privacy

| Control | Statement | Reading it here |
|---|---|---|
| MASVS-PRIVACY-1 | The app minimizes access to sensitive data and resources. | Declared permissions vs. what the app actually uses. |
| MASVS-PRIVACY-2 | The app prevents identification of the user. | Analytics, ad IDs, fingerprinting. Often trivially met — say so. |
| MASVS-PRIVACY-3 | The app is transparent about data collection and usage. | Crash reporting is collection. Flavours that differ (Play vs F-Droid) differ here too. |
| MASVS-PRIVACY-4 | The app offers user control over their data. | Can the user clear the cache and the stored credential from inside the app? |

## Getting the current MASTG tests for a control

**Don't hardcode test IDs.** MASTG renumbered when it restructured, and third-party
mappings in the wild still cite retired legacy IDs. Fetch the live list:

```bash
gh api repos/OWASP/owasp-mastg/git/trees/master?recursive=1 --jq '.tree[].path' \
  | grep -E '^tests-beta/android/MASVS-NETWORK/'          # swap platform and category
```

Tests are grouped by `tests-beta/<platform>/<MASVS-CATEGORY>/MASTG-TEST-<id>.md`, so the
directory *is* the mapping. Counts as of the last check: Android 112 tests across the
eight categories, iOS 88. Read an individual test with:

```bash
gh api repos/OWASP/owasp-mastg/contents/tests-beta/android/MASVS-STORAGE/MASTG-TEST-0200.md \
  --jq '.content' | base64 -d
```

Most of them are dynamic. Cite a test ID only when you actually applied it, or when
listing what still needs a device.
