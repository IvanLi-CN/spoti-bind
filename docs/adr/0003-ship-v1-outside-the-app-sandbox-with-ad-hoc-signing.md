# Ship V1 outside the App Sandbox with Ad Hoc universal distribution

V1 is a non-sandboxed macOS app signed Ad Hoc because it needs Accessibility-based event capture and must launch the person's separately installed Fastpotify executable, while no Developer ID certificate is available. It will be distributed through GitHub Releases as one compressed universal (`arm64` and `x86_64`) DMG with `SHA256SUMS`, without notarization; the installation guidance must clearly describe the resulting Gatekeeper and quarantine experience.

## Consequences

The project does not target the Mac App Store. The universal bundle duplicates only architecture-specific executable slices; its resources and system frameworks remain shared, and the current Mac loads only its native slice. A verified preparation commit merged to `main` builds and validates the artifact, then publishes a public GitHub Release through the identity-bound workflow. The existing Ad Hoc/Gatekeeper caveat remains, while real-Mac checks are recorded as post-release evidence. A future Developer ID and notarization path can replace the distribution method without changing the core routing contract, but it must add signed-release verification and revised installation documentation. See ADR-0009 for the release decision.
