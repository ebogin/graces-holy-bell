# App Store Connect — "App Privacy" answers (Phase 4)

> Drafted 2026-06-27 alongside the privacy-policy rewrite. Enter these in
> App Store Connect → your app → **App Privacy**. This replaces the prior
> **"Data Not Collected"** answer, which became inaccurate when the PostHog
> analytics shipped. Source of truth for *what* is collected:
> `Graces Holy Bell/Utilities/PostHogTransport.swift`, the event taxonomy in
> `Shared/Analytics/Events/`, and the consent gate in `Shared/Analytics/Consent/`.

## TL;DR
The app now collects exactly two Apple data types, **both via PostHog analytics
only**, both **not linked to identity** and **not used for tracking**, purpose
**Analytics**:

| Apple data type | Category | Linked to identity? | Tracking? | Purpose |
|---|---|---|---|---|
| **Device ID** | Identifiers | No | No | Analytics |
| **Product Interaction** | Usage Data | No | No | Analytics |

Everything else (prayer logs, Amen Alarm settings) stays on device and is **not
collected**. The waitlist is a separate website form — see "Waitlist" below for
why it is not part of the app's privacy label.

## Step-by-step answers

1. **"Do you or your third-party partners collect data from this app?"** → **Yes.**

2. Select these data types:
   - **Identifiers → Device ID**
   - **Usage Data → Product Interaction**

3. For **Device ID**:
   - *Used to track you?* **No** (no cross-app/website tracking; `NSPrivacyTracking = false`).
   - *Linked to your identity?* **No** (it's a random install-scoped UUID — the
     analytics `distinctId` — not tied to any account, name, email, or Apple ID).
   - *Purpose:* **Analytics.** (Not "App Functionality", not "Developer's
     Advertising or Marketing".)

4. For **Product Interaction** (the §2 event taxonomy: session start/end, prayer
   cadence in coarse buckets, session value, feature use, app/OS/device version —
   **never prayer content**):
   - *Used to track you?* **No.**
   - *Linked to your identity?* **No.**
   - *Purpose:* **Analytics.**

That's the whole label. Do **not** add Location (see GeoIP note), Contact Info,
Health, Financial, Browsing History, Search History, or Sensitive Info.

## Why these two, and not others

- **Device ID, not "User ID":** the install_id is device/install-scoped and not
  tied to an account, so Apple's *Device ID* is the right bucket. PostHog also
  generates its own anonymous device id; same bucket covers it.
- **Product Interaction:** the events describe how the app is used. Per the
  project vision this is *prayer-duration/cadence awareness* in broad buckets —
  not content, not free text.
- **No Crash/Performance Data:** no crash-reporting or APM SDK is wired (PostHog
  error tracking is not enabled here).
- **App / OS / device version** ride on events as context. They are not a
  standalone Apple data type that requires separate declaration; they're covered
  under Product Interaction. (If App Review ever pushes back, the conservative
  add is *Diagnostics → Other Diagnostic Data*, same answers: not linked, not
  tracking, Analytics.)

## GeoIP / approximate location — important, please decide

PostHog's servers derive an **approximate location from the IP address** at
ingestion. Verified empirically on the live test events: they carried
`$geoip_country_name = United States` and **`$geoip_city_name = Los Angeles`**
(the raw `$ip` is not stored as a queryable property, but the city/country are).

- **Apple label:** this is **not** declared under *Location*. Apple's *Coarse/
  Precise Location* data types refer to location from the device's **location
  services**, which this app never uses. IP-derived geo from a third party falls
  outside that definition, so the label stays as the two types above. The
  human-readable **privacy policy does disclose it** (the "Anonymous Analytics"
  section says PostHog's servers may estimate an approximate country/city from
  the IP), which is the honest, broader standard.
- **Recommendation (Eric's call):** if you'd rather the analytics store **no
  location at all** — which fits this app's ethos and removes any ambiguity —
  turn on **"Discard client IP data"** in PostHog → *Project Settings* (and/or
  set `$geoip_disable`). City-level geo on a prayer app is more than we need. If
  you do this, no policy/label change is required (the policy already covers the
  off switch), but I can soften the IP paragraph to match. Leaving GeoIP on is
  also defensible given the disclosure — your choice.

## Waitlist (email / name / phone / country / SMS consent)

The waitlist (Cloudflare Worker → D1, emails via Resend, optional SMS consent)
collects Contact Info, but it is a **web form on boginfactory.com** that the user
opens in a browser from "Share with a Friend" — the app binary doesn't collect or
transmit it. Apple's App Privacy covers data collected *by the app and its
SDKs*. The standard reading is that this website signup is **not** part of the
app's privacy label; it's covered by the **website's** privacy policy (which we
publish at the same URL). The in-app/web policy already discloses it in full.
- If you prefer maximum caution, you *could* additionally declare *Contact Info →
  Email / Name / Phone Number* (purpose: Developer's Marketing; not linked is hard
  to argue here, so it'd be "linked"). Not recommended unless Review asks, since
  the app itself never sees these fields.

## xcprivacy manifests (already updated in this branch)

- **`Graces Holy Bell/PrivacyInfo.xcprivacy`** — now declares `Device ID` +
  `Product Interaction`, both `Linked = false`, `Tracking = false`, purpose
  `Analytics`. Keeps the existing `UserDefaults` (CA92.1) required-reason API.
- **`Graces Holy Bell Watch App Watch App/PrivacyInfo.xcprivacy`** — unchanged
  (no collection). Correct: PostHog is **iPhone-target only**; under Option A the
  Watch is a thin proxy and never transmits to PostHog itself.
- PostHog's Swift SDK ships its own bundled privacy manifest for the
  required-reason APIs it calls; Xcode aggregates it into the app's nutrition
  label, so we don't restate the SDK's API reasons in our manifest.

## Loose end noted while here
`PostHogTransport.swift:26` uses the deprecated `PostHogConfig(apiKey:host:)` —
swap to `init(projectToken:host:)` at some point (warning only, not blocking).
