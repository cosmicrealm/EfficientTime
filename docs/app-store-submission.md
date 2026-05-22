# EfficientTime Mac App Store Submission Guide

This document records what is already prepared in the repository and what still needs the Apple Developer account holder to complete before submitting EfficientTime to the Mac App Store.

## Current Repository Preparation

- App category is set to `public.app-category.productivity` in the generated `Info.plist`.
- `scripts/build_app_bundle.sh` accepts `BUNDLE_ID`, `VERSION`, `BUILD_NUMBER`, and `MINIMUM_SYSTEM_VERSION`.
- `Resources/PrivacyInfo.xcprivacy` is copied into the app bundle.
- `Resources/Entitlements/AppStore.entitlements` enables the macOS App Sandbox, outbound network access, and microphone input.
- `scripts/package_app_store.sh` builds, embeds the provisioning profile, signs the app, and creates an App Store upload package.

## Account And App Store Connect Setup

You need an Apple Developer Program membership. Create the app in App Store Connect with:

- Platform: `macOS`
- Name: `EfficientTime`
- Bundle ID: recommended `com.cosmicrealm.EfficientTime`
- SKU: for example `efficienttime-macos`
- Primary category: `Productivity`
- Pricing: choose free or paid in App Store Connect

Apple requires App Store product metadata such as name, icon, description, screenshots, keywords, privacy details, and age rating before submission.

## Signing Assets Needed

Create or download these in the Apple Developer account:

- Bundle ID / App ID matching `com.cosmicrealm.EfficientTime`
- Mac App Store distribution provisioning profile for that Bundle ID
- App signing identity, usually visible in Keychain as `Apple Distribution: ...`
- Installer signing identity, usually `3rd Party Mac Developer Installer: ...`

The Mac App Store requires App Sandbox. EfficientTime currently requests these sandbox entitlements:

```text
com.apple.security.app-sandbox
com.apple.security.network.client
com.apple.security.device.audio-input
```

Why:

- `network.client`: AI planning providers use HTTPS requests.
- `device.audio-input`: voice input uses the microphone.
- local schedules and settings are stored inside the app container.

## Build App Store Upload Package

After the certificates and provisioning profile are installed locally:

```bash
APP_SIGNING_IDENTITY="Apple Distribution: Your Name (TEAMID)" \
INSTALLER_SIGNING_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAMID)" \
PROVISIONING_PROFILE="/path/to/EfficientTime_AppStore.provisionprofile" \
BUNDLE_ID="com.cosmicrealm.EfficientTime" \
./scripts/package_app_store.sh 0.02
```

Output:

```text
dist/EfficientTime-0.02-AppStore.pkg
```

Upload the package with Apple Transporter or Xcode Organizer. Because this project is currently SwiftPM-first rather than an Xcode project, Transporter is the simpler upload path after `productbuild` succeeds.

## Privacy Answers

EfficientTime is local-first and has no account system or built-in analytics. However, privacy answers depend on the final product behavior:

- If AI planning is enabled, users may send free-form plan text to the selected AI provider. This can count as user content handled by a third party depending on retention and processing terms.
- If voice input is used only to transcribe into the local text field and audio is not stored by EfficientTime, the app still needs microphone and speech recognition permission prompts.
- If no analytics, advertising, tracking, crash reporting, or account system is added, keep those answers as not collected / not used.

Prepare:

- Public privacy policy URL
- Support URL
- A clear statement that API keys and schedules are stored locally
- A clear statement about optional AI provider calls and what text is sent

## Product Page Draft

Subtitle:

```text
AI daily schedule and focus panel
```

Short description:

```text
EfficientTime turns rough task notes into a clear daily schedule, then keeps your current task, countdown, nearby tasks, and completion status visible while you work.
```

Keywords:

```text
schedule, planner, focus, productivity, time blocking, AI planner, reminder
```

What to emphasize:

- Local-first macOS daily execution assistant
- AI-generated editable schedule drafts
- Always-visible floating execution panel
- Start/end reminders
- Clickable 24-hour status clock

## Review Risks To Check Before Submission

- The app is currently not a full Xcode project. If Transporter rejects the package, create an Xcode app target that wraps the same sources and use Xcode Organizer.
- Confirm the sandboxed build can still read/write local schedules and Keychain secrets.
- Confirm microphone and speech recognition permission prompts work from the App Store-signed build.
- Confirm AI requests work with `network.client` and without extra sandbox exceptions.
- Confirm the app does not expose user API keys in screenshots, logs, or review notes.
- Provide App Review notes explaining that DeepSeek / Volcengine Ark API keys are optional user-configured integrations.

## Useful Apple References

- Mac distribution and Mac App Store sandboxing: https://developer.apple.com/macos/distribution/
- Xcode distribution methods: https://help.apple.com/xcode/mac/current/en.lproj/dev31de635e5.html
- App Store submission/product page/privacy overview: https://developer.apple.com/app-store/submitting/
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Required reason APIs and privacy manifests: https://developer.apple.com/documentation/BundleResources/describing-use-of-required-reason-api
