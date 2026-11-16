# Documentation index

> **Directives (mandatory for every contributor and AI agent)**
> 1. **Read this documentation before acting.** Start with `PREMISES.md`, then the doc relevant to your task.
> 2. **Always keep the documentation updated.** Any change to behavior, features, architecture, premises, commands or dependencies must update the matching doc in the same change.
> 3. **Keep `PRIVACY_POLICY.txt` accurate.** Any change to what is stored on the device, what is sent over the network, permissions (`AndroidManifest.xml`) or third-party SDKs/services must update the policy and its "Last updated" date in the same change.

| File | Contents |
|---|---|
| [PREMISES.md](PREMISES.md) | What the app is, constraints and decisions that must hold |
| [FEATURES.md](FEATURES.md) | Feature list per screen, with the Radarr endpoints used |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Code layout, data flow, build/test commands, CI/CD |
| [PLAYBOOK.md](PLAYBOOK.md) | Environment gotchas, release pipeline, Google Play and screenshot workflow |
| [../PRIVACY_POLICY.txt](../PRIVACY_POLICY.txt) | Plain-text privacy policy. **Update it (and its "Last updated" date) if the app starts storing/sending new data, adds a third-party SDK/service, or requests new permissions.** |
| [../assets/images/screenshots/](../assets/images/screenshots/) | Store/README screenshots (taken manually, see PLAYBOOK). Captured on the `radarr_pixel` emulator with the in-app demo mode. **Retake when the UI changes.** |
