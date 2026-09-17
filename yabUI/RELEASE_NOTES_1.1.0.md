# yabUI 1.1.0

This release hardens the first-run and service lifecycle experience:

- uses a dedicated `com.yabui.runtime` launch service instead of recreating the legacy service label
- keeps service checks off the main UI thread so stopping, starting, or restarting does not freeze the interface
- treats unavailable and transitional states as calm, recoverable UI states instead of repeated warning banners
- adds a four-step onboarding flow for Accessibility permission and recommended setup
- adds GitHub release checking and DMG download support in Settings
- builds a universal app binary and verifies the signed app bundle before packaging
- requires a bundled runtime at release build time so an incomplete installer cannot be published
