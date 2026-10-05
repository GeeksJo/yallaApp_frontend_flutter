# Promo interstitial (house ads)

Parent: [ADS.md](ADS.md).

Full-screen cross-promo creatives served from Majoon Studio. They occupy an
interstitial slot so hosts do not add a new ad network or ship hardcoded
dialogs. The backend decides what to promote; the kit only fetches, caches,
and shows.

## How to turn it on

Keep the usual interstitial handler. Set one flag:

```dart
ads: AdsConfig(
  // ...
  showPromoInterstitial: true,
),
```

```dart
onShouldShowInterstitial: () => GameKit.ads.runInterstitialCycle(),
```

Leave the flag **off** on the app being promoted. The kit also skips any
campaign whose `promoted_package` matches `crossPromoAppIdentifier`.

## Slot behavior

Same cadence as a network interstitial: `levelCompleted` → `onShouldShowInterstitial` →
`runInterstitialCycle`. Shared cooldown (40s) and session cap apply to
**both** house ads and the ad network.

Until a campaign is exhausted: **promo, network, promo, network**. The first
slot is promo. A shown house ad **replaces** the ad network for that slot (closing
it skips the ad network). No eligible campaign, image not ready, or missing overlay
falls through to the ad network **without burning** the promo turn.
`adClosed()` runs after either fullscreen. The remove-ads popup only
follows a shown ad-network slot, never a house-ad slot.

### Multiple campaigns (priority lock)

Walk the server-sorted list top-down. The highest-priority eligible campaign
owns every promo turn until the user converts or dismisses it
`max_dismissals` times; then the next eligible campaign takes over.

## Stop rules (per campaign id)

| User action                                         | Result                                |
| --------------------------------------------------- | ------------------------------------- |
| Opens store (CTA or phone preview)                  | Never show that campaign again        |
| Taps CTA but the store does not open                | Ad stays up; not counted as converted |
| Dismisses with X                                    | Can show again on the next promo turn |
| Dismisses with X `max_dismissals` times (default 4) | Never show that campaign again        |

A new campaign `id` starts a fresh budget. Copy comes from the API (EN/AR);
kit l10n only supplies Close + a CTA fallback.

## Never-glitch / API failure

Show path never touches the network. A campaign is eligible only when its
JSON **and** image are already on disk. A failed fetch (offline, timeout,
HTTP error, `success: false`) **keeps the previous cache** and is not recorded
as a fetch; the next attempt waits 2 minutes. Only a successful response with
an empty list clears the campaigns.

## Cache / refresh

- Endpoint (fixed in package): `https://majoonstudio.com/api/promo-ads`
- Disk-first hydrate on `GameKit.initialize` (non-blocking)
- Soft refresh when cache is older than **15 minutes** (init + after each
  interstitial slot). No TTL - last good campaign serves until replaced.

## Backend contract

`GET /api/promo-ads?app_identifier=<id>&package_id=<bundle id>&platform=android|ios`

| Param | Value | Why |
|---|---|---|
| `app_identifier` | Android: Play package name. iOS: **numeric App Store track id** | What the API keys off today. Sending the bundle id on iOS is a 422. |
| `package_id` | Bundle / package id on **both** platforms | Lets the backend exclude campaigns promoting the app the player is already in. Sent on every request, so it is safe to require server-side. Omitted only when the platform cannot report one, so a required-field error is loud rather than silently matching `""`. |
| `platform` | `android` / `ios` / `web` | Picks the store url field. |

The kit also filters client-side (`campaign.promotesHost`), so self-promotion is
blocked even against an older backend.

- **Android:** Play package name (`GameKitConfig.crossPromoAppIdentifier`).
- **iOS:** numeric App Store track id (`ShareConfig.iosAppId`). The backend
  422s a bundle id on iOS.

```json
{
  "success": true,
  "data": [
    {
      "id": "sawaleef-launch-2026",
      "title": { "en": "Meet Sawaleef", "ar": "تعرّف على سواليف" },
      "description": { "en": "...", "ar": "..." },
      "cta": { "en": "Try Sawaleef free", "ar": "جرّب سواليف مجاناً" },
      "badge": { "en": "New", "ar": "جديد" },
      "image": "https://majoonstudio.com/promo/sawaleef-launch-2026-v1.png",
      "android_url": "https://play.google.com/store/apps/details?id=com.geeksjo.taqtaqah",
      "ios_url": "https://apps.apple.com/app/id6760083618",
      "promoted_package": "com.geeksjo.taqtaqah",
      "colors": {
        "background_top": "#1B6B35",
        "background_bottom": "#0F3D1F",
        "accent": "#E8C547",
        "cta_text": "#0F3D1F",
        "badge_background": "#FFC107",
        "badge_text": "#7A4E00"
      },
      "max_dismissals": 4,
      "priority": 10
    }
  ]
}
```

`cta` and optional `badge` are localized button/label copy. `colors` are
optional hex (`#RGB` / `#RRGGBB`); omitted keys fall back to the Sawaleef
green/gold defaults. `accent` drives the CTA button fill, gold rule, and
phone-frame border; `cta_text` is the CTA label color.

Hard rules for the backend: stable `id`, immutable image URLs (version
suffix on creative change), server-side exclude self-promos and inactive
campaigns, sort by `priority` descending, always include EN+AR strings.

## Analytics (`GameAnalytics`)

Logged to the host app's own property. Full parameter list:
[ANALYTICS.md](ANALYTICS.md#house-ads-promo-campaigns---see-promo_adsmd).

| Question | Events |
| --- | --- |
| How often is each campaign seen, and on which showing? | `promo_ad_shown` (`campaign_id`, `promo_slot`, `impression`) |
| Does it convert? | `promo_ad_clicked` (`source`, `store_opened`) ÷ `promo_ad_shown` |
| How often is it closed? | `promo_ad_dismissed` (`impression`, `max_dismissals`) |
| Why did it stop for a player? | `promo_ad_retired` (`reason`: `converted` / `max_dismissals`) |
| Could it show at all? | `promo_ad_unavailable`, `promo_ad_image_failed`, `promo_ad_fetch_failed` |
| When did players get a new list? | `promo_ad_catalog_changed` |

`placement` is `promo_ad_interstitial`. `promo_slot` is `interstitial` or
`rewarded_fallback`. Per-campaign, per-app queries:
[CROSS_APP_REPORTING.md](CROSS_APP_REPORTING.md).
Back/barrier taps do not dismiss.
