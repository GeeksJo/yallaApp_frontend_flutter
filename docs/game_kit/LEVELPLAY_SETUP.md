# LevelPlay host setup

What a host app must do that `game_kit` **cannot do for it**. Read this before
wiring ads into a new app, and when an app "has ads configured" but serves none.

Parent: [ADS.md](ADS.md) · grant chain [AD_GRANT.md](AD_GRANT.md)

---

## 1. Network adapters are the host's job

`game_kit` is a **pure Dart package** - it has no `android/` or `ios/` directory,
so it cannot declare native dependencies. The `unity_levelplay_mediation` plugin
ships only `com.unity3d.ads-mediation:mediation-sdk`, the mediation **core**.
Every network adapter is a separate artifact, and on **Android** a network's own
SDK is **not** pulled in transitively by its adapter (on iOS it is - see below).

So each host app declares the adapters it needs. For Unity Ads, in
`android/app/build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.unity3d.ads-mediation:unityads-adapter:5.5.0")
    implementation("com.unity3d.ads:unity-ads:4.16.6")
}
```

`mavenCentral()` must be in the repositories (Flutter templates already have it).
Other networks follow the same shape; get the current coordinates from
[LevelPlay's Android mediation networks page](https://docs.unity.com/en-us/grow/levelplay/sdk/android/mediation-networks).

### iOS is the same job in a different file

The plugin's podspec depends on `IronSourceSDK` - again the core only - so the
adapters go in the host `ios/Podfile`:

```ruby
target 'Runner' do
  use_frameworks! :linkage => :static
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  pod 'IronSourceUnityAdsAdapter'
end
```

Static linkage is required because `IronSourceSDK` ships a static xcframework.
Dynamic `use_frameworks!` makes `pod install` fail on that binary. The same
static frameworks then surface a Clang error: `google_mobile_ads` public
headers import `GoogleMobileAds_Beta.h`, which the Google Mobile Ads SDK keeps
in `PrivateHeaders`. Set
`CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES` on every pod
target in `post_install`, and on the Runner target via
`ios/Flutter/Debug.xcconfig` and `Release.xcconfig`.

Two differences from Android worth knowing:

- **Leave the adapter unpinned.** It has to match the `IronSourceSDK` version
  the plugin pulls, and CocoaPods resolves that pairing more reliably than a
  hand-picked number. `pod install` writes the resolved version into
  `Podfile.lock`, which is what you commit.
- **The network SDK comes along for free.** On iOS the adapter declares the
  network SDK as its own dependency, so there is no second line the way
  `com.unity3d.ads:unity-ads` is needed on Android.

Run `pod install --repo-update` after adding one; a plain `pod install` often
cannot see a newly published adapter version.

Also host-side on iOS: `SKAdNetworkItems` in `Info.plist` (take the list from
LevelPlay's networks page, not AdMob's), and - if you want IDFA-level fill - an
ATT prompt. Note that **neither the plugin nor `game_kit` requests ATT**, so
adding `NSUserTrackingUsageDescription` on its own changes nothing: the host
has to call `ATTrackingManager` itself. Without it the app runs on
non-personalised inventory, which is a revenue choice rather than a bug.

**The failure is silent.** With the adapter missing, everything looks correct -
the SDK initialises, the dashboard shows the instance live - and no ad ever
loads. The only clue is in logcat:

```
AdapterRepository: Error while loading adapter - exception = com.ironsource.adapters.unityads.UnityAdsAdapter
AdapterRepository: UnityAds adapter was not loaded
c a - error creating network adapter UnityAds_<instanceId>
```

If ads never serve, grep logcat for `adapter was not loaded` first. It costs
seconds and rules out the most likely cause.

---

## 2. Three things must be "live", and only one is obvious

A dashboard can show an app as live while ads still never serve, because there
are three independent layers:

| Layer | Where you check it | Symptom when wrong |
|---|---|---|
| **App** | apps list - says `active` | rarely the problem |
| **Instance** | per network per ad unit - `isLive` | network never bids |
| **Mediation group** | instance's `groups: [...]` | **instance is live but in no auction** |

The third is the one that catches people. An instance with `isLive: true` and
`groups: []` never enters an auction, and the SDK reports it as missing
configuration:

```
configurations( RewardedVideoConfigurations{...}, null, null, null )
                                                  ^ interstitial, banner, native
```

Those `null`s mean "this ad format has no usable configuration", and
`LevelPlayInitListener.onInitSuccess` never fires, so the kit never attempts a
load. A healthy app shows every format configured, and each instance carries a
non-empty `groups` list shared with the other networks on that ad unit.

**Mediation groups are scriptable.** LevelPlay's Groups API v4 does full CRUD
(`GET/POST/PUT/DELETE /levelPlay/groups/v4/{appKey}`), so
`levelplay.mjs create-groups <appKey>` makes the missing groups for you. Omitting
`instances` from the body makes LevelPlay include every instance of that ad
format, which is what a default "All Countries" group should do.

A network also has to be **connected at the account level** before its instances
can go live. Check `networkReportingApi` on the app: a working app reads
`{"ironSource": "verified", "UnityAds": "verified"}`. A network missing there is
why its instances stay `isLive: false` and its dashboard controls stay greyed.

---

## 3. Testing on an Android emulator

Two settings decide whether you see anything.

**Enable GPU emulation, or video ads cannot render.** An emulator with
`hw.gpu.enabled = no` runs software rendering. Static creatives (banners, image
interstitials) still display, so ads look like they work - but a video creative
shows a black screen and then:

```
UnityAds: ... error: [UnityAds] Timeout while trying to show
UnityAdsRewardedVideoAdListener onUnityAdsShowFailure
```

This is not an SDK or code fault, and it is unrelated to the API level - a
current API 35 image fails exactly the same way. Fix it in
`~/.android/avd/<name>.avd/config.ini`:

```ini
hw.gpu.enabled = yes
hw.gpu.mode    = host
hw.ramSize     = 4096
```

or launch with `emulator -avd <name> -gpu host -memory 4096`. Restart the
emulator afterwards; the app survives the restart.

Note that the grant chain hides this failure by design: a rewarded ad that fails
to show is "not earned", so `requestAdGrant` falls through and the player is
granted anyway. **An instant reward with no ad is the signature of this
problem**, not evidence that the reward logic is broken.

**Test devices and test mode are two different things.** This trips people up,
so be precise about which problem each one solves:

| | What it does |
|---|---|
| **Test device** registration | Anti-fraud only. Unity: *"To safely test without being flagged for fraud, you must register your test devices."* It does **not** change which ads serve. |
| **Test mode** | The switch that serves test ads. Unity: *"Test Mode ensures test ads are shown instead of live ads to prevent test clicks or impressions from affecting your real ad metrics."* |

Registering a device does **not** give you test creatives. A registered device on
an app with test mode off still sees real advertiser campaigns; the registration
only stops that activity being treated as fraud.

So do both:

1. Register the device - `levelplay.mjs unity-add-test-device --name N --advertising-id ID`
2. Turn on test mode - Unity dashboard, **Current Project > Settings > Test mode**,
   with per-device settings under **Testing**

The API exposes only app-wide test mode (`unity-set-testmode`, values `forceAll`,
`forceOff`, `default`). `forceAll` serves test creatives to **every** user of that
app and takes its revenue to zero until reverted, so on a live app use the
dashboard's per-device settings instead.

Until test mode is on, treat every ad as real: impressions are real impressions
and **a click is a real click on an advertiser's budget**, registered device or
not. Look, let it run, close it - do not tap the install button.

An emulator's advertising ID can change when the AVD is wiped or reconfigured -
re-check it after either, or the registration silently stops applying.

---

## What still needs the dashboard

Almost everything is scriptable through `levelplay_tools_node`. Only three things
genuinely are not:

| Dashboard-only | Why |
|---|---|
| **Connecting a network to your account** | No API. Until a network is connected, its instances stay `isLive: false` and its dashboard controls are greyed out. |
| **Editing an app after creation** | Application API v6 is GET and POST only - no PUT or PATCH. Name, taxonomy, COPPA and CCPA are fixed at creation, so get them right first time. |
| **Per-device test mode** | The API exposes only app-wide `forceAll` / `forceOff` / default. |

Everything else - apps, ad units (including pausing one), instances, mediation
groups, placements, Unity apps and placements, test devices and app-wide test
mode - has an endpoint.

## Quick checklist for a new app

- [ ] Network adapter (+ network SDK on Android) in `android/app/build.gradle.kts` **and** `ios/Podfile`
- [ ] LevelPlay app created, ad units created
- [ ] Network connected at account level (`networkReportingApi` verified)
- [ ] Instances created and `isLive`
- [ ] **Mediation group per ad unit** - `levelplay.mjs create-groups <appKey>`
- [ ] Test device registered **and** test mode on - they are different things
- [ ] Emulator GPU enabled, if testing on one
- [ ] logcat shows `onInitSuccess`, then `Successfully loaded ad for placement …`
