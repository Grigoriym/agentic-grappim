---
name: masvs-review
description: Review a mobile app against OWASP MASVS v2 from its source, and maintain the
  project's security register in docs/security/masvs.md. Use when the user asks for a
  security review of a mobile app, names a MASVS category or control, asks "is our token
  storage safe", "are we leaking anything", "check the cert handling", or wants a
  compliance checklist. Not for reviewing a pending diff — that is /security-review.
metadata:
  author: grappim
  keywords:
  - masvs
  - mastg
  - mobile security
  - security review
  - security audit
  - owasp
  - secure storage
  - certificate pinning
---

Reviews an app against the OWASP MASVS v2 controls **from source**, and records the
result — including deliberate deviations — in `docs/security/masvs.md`.

Two things make this different from a generic security pass:

- **The register comes first.** These are self-hosted clients. Cleartext HTTP, a custom
  trust manager and a user-supplied server URL are *features* here, and a review that
  re-raises them every run is noise. Deviations get recorded once, with their bounds.
- **A code read is not a verification.** Much of MASTG is dynamic. Say what was checked
  statically and name what still needs a device or an APK.

## Step 0. Scope

Default to **one MASVS category per run**. A whole-app pass is eight categories and
produces a report nobody finishes reading — do it only when asked, and write it
category by category.

Establish and write down, before checking anything:

| | |
|---|---|
| Platforms | Android / iOS — from the declared KMP targets |
| Sensitive assets | what would actually hurt: stored credential, cached user data, PII |
| Server trust model | vendor-operated, or **self-hosted and user-supplied** |

**MASVS covers Android and iOS only.** A JVM/desktop target is outside the standard —
say so rather than inventing controls for it.

**MASVS-RESILIENCE is out of scope for a self-hosted FOSS client** unless the user says
otherwise. Anti-tamper and obfuscation protect a vendor's assets against the device
owner; a client for a server the user owns has no such asset. Record the decision in the
register instead of re-deciding it. Reproducible builds are the thing that matters here,
and MASVS does not cover them.

## Step 1. Read the register first

`docs/security/masvs.md`, if it exists. Every row marked **Accepted** is settled — do
not re-report it as a finding. Two things are still fair game:

- **The bound moved.** The register says the custom trust manager only trusts certs the
  user explicitly accepted; the code now trusts more than that. That is a new finding,
  and it is the most valuable kind this review produces.
- **The rationale expired.** "Pre-v1, nothing is installed yet" stops being true at
  release.

If there is no register, Step 4 creates it.

## Step 2. Check

`references/masvs-controls.md` has the 24 controls and how to pull the current MASTG
test list for a category. `references/kmp-checks.md` has the concrete checks for this
stack — Ktor, DataStore, Room, Compose, KMP source sets — which is where the generic
mobile advice (OkHttp, Retrofit, TrustKit) does not apply.

Rules that keep the output honest:

- **Every finding needs `file:line` and the code.** A finding you cannot point at is a
  guess; say it is one, or drop it.
- **Check every source set.** A KMP app can pass in `commonMain` and fail in an
  `androidMain` actual. Grep the source sets separately, and name which platform a
  finding applies to.
- **An absent control is not automatically a finding.** No pinning, no biometric
  re-auth, no root detection — decide whether it applies to *this* app's threat model
  first. MASVS-NETWORK-2 in particular assumes endpoints under the developer's control,
  which a self-hosted client does not have.
- **A deliberate weakening is a finding only if it is unbounded or undocumented.**
  Report what bounds it, then propose the register row.

## Step 3. Separate what you verified from what you didn't

Three buckets, and the third is not optional:

1. **Verified statically** — the code says so, with a reference.
2. **Needs a device or an APK** — the merged manifest, backup contents, screenshots in
   the recents list, TLS behaviour on the wire, whether R8 left anything in. Name the
   check; do not report it as passing.
3. **Not checked** — out of profile, or out of scope.

**Never state or imply MASVS compliance from a source read.** The bucket-2 list is the
reason. This is the same failure as claiming a controlled-vocabulary standard you cannot
verify against: an unfalsifiable pass is worse than an honest gap.

## Step 4. Write the register

`docs/security/masvs.md`. Structure:

```markdown
# MASVS register

Profile: <platforms> · <server trust model> · reviewed <date>, <categories> only.
Out of scope: MASVS-RESILIENCE (<one line why>), desktop target (outside MASVS).

## Accepted deviations

| Control | What we do instead | Bound | Why |
|---|---|---|---|
| MASVS-NETWORK-1 | cleartext permitted | <the bound> | self-hosted LAN instances |

## Open

| Control | Finding | Where | Severity |
|---|---|---|---|

## Needs a device or an APK

| Control | Check | Why source can't answer it |
|---|---|---|
```

The **Bound** column is the point of the table. "Cleartext is allowed" is not a decision;
"cleartext is allowed, and here is what stops it applying to the credential" is.

Then:

- A finding worth fixing now → fix it, or write it into the project's
  `docs/revisit.md` (or its equivalent). Not chat.
- A finding you fixed → it leaves the register. Don't accumulate history there; git has it.

## Step 5. Report

Say, in this order: the profile you scoped to, what you verified, the open findings
worst-first, and **what you could not check from source**. If the register gained an
accepted deviation, say so explicitly — that is a decision the user is making, not a
note you filed.
