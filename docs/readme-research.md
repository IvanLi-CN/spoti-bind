# README Structure Research

This note records a small set of first-party README patterns to guide the
English `README.md` and the linked Chinese variant for SpotiBind. The examples
are mature macOS utilities with a similar user-facing scope; the wording below
is a structural recommendation, not copy to reuse verbatim.

## Primary sources

- [Rectangle README](https://github.com/rxhanson/Rectangle/blob/master/README.md)
  - MIT-licensed macOS menu-bar utility for window management.
- [Maccy README](https://github.com/p0deje/Maccy/blob/master/README.md)
  - MIT-licensed lightweight macOS menu-bar utility.
- [MonitorControl README](https://github.com/MonitorControl/MonitorControl/blob/master/README.md)
  - macOS menu-bar utility with hardware-key input and an explicit Accessibility
    setup path.
- [Ice README](https://github.com/jordanbaird/Ice/blob/main/README.md)
  - macOS menu-bar utility with a visual product introduction and grouped
    feature status.
- [BeardedSpice README](https://github.com/beardedspice/beardedspice/blob/master/README.md)
  - media-key routing utility whose README explains the user workflow and
    supported targets.
- [SpotiBind LICENSE](../LICENSE)
  - The repository's authoritative MIT license text.

## What the references do well

### Maccy: compact utility flow

Maccy opens with a product identity, one-sentence explanation, platform
baseline, and a short feature list. It then uses a predictable sequence:
`Install`, `Usage`, `Advanced`, `FAQ`, optional project context, and `License`.
Its numbered usage section translates the product promise into concrete
keyboard actions, while the FAQ catches common Accessibility and shortcut
problems. This is the closest high-level shape for a small, keyboard-first
SpotiBind README.

Source sections: [Features](https://github.com/p0deje/Maccy/blob/master/README.md#features),
[Install](https://github.com/p0deje/Maccy/blob/master/README.md#install),
[Usage](https://github.com/p0deje/Maccy/blob/master/README.md#usage),
[FAQ](https://github.com/p0deje/Maccy/blob/master/README.md#faq), and
[License](https://github.com/p0deje/Maccy/blob/master/README.md#license).

### MonitorControl: permission-aware onboarding

MonitorControl places the download path, major capabilities, screenshots, and
the install/use sequence close to the top. Its numbered onboarding explicitly
states when Accessibility is needed, where the user enables it in macOS System
Settings, and what can still work without that permission. It also separates
compatibility and supported hardware from the basic install path. SpotiBind
should use the same explicitness for Accessibility, macOS 13+, the player
requirements, and the difference between a selected player and an installed
player.

Source sections: [Download](https://github.com/MonitorControl/MonitorControl#download),
[Major features](https://github.com/MonitorControl/MonitorControl#major-features),
[How to install and use the app](https://github.com/MonitorControl/MonitorControl#how-to-install-and-use-the-app),
[macOS compatibility](https://github.com/MonitorControl/MonitorControl#macos-compatibility),
and [Contributing](https://github.com/MonitorControl/MonitorControl#contributing-to-the-project).

### Rectangle: practical operation and troubleshooting

Rectangle starts with a brief product description and screenshot, then gives
system requirements and installation before explaining the primary interaction.
Its later sections document advanced workflows, supported command surfaces,
known issues, troubleshooting, preferences, uninstallation, contribution, and
developer setup. The useful pattern for SpotiBind is to keep the first screen
focused on the happy path, while putting detailed event, preference, reset,
and diagnostic behavior in named sections or linked docs.

Source sections: [System Requirements](https://github.com/rxhanson/Rectangle/blob/master/README.md#system-requirements),
[Installation](https://github.com/rxhanson/Rectangle/blob/master/README.md#installation),
[How to use it](https://github.com/rxhanson/Rectangle/blob/master/README.md#how-to-use-it),
[Common Known Issues](https://github.com/rxhanson/Rectangle/blob/master/README.md#common-known-issues),
[Uninstallation](https://github.com/rxhanson/Rectangle/blob/master/README.md#uninstallation),
and [Contributing](https://github.com/rxhanson/Rectangle/blob/master/README.md#contributing).

### Ice: visual identity and grouped features

Ice uses a centered icon/name introduction, a short positioning statement,
download/platform badges, and a banner before installation. Its feature list
is grouped by user-facing areas and uses checked/unchecked items to distinguish
available functionality from its roadmap. This is useful if SpotiBind later
needs a roadmap, but a small stable README should avoid presenting speculative
features as commitments.

Source sections: [Install](https://github.com/jordanbaird/Ice/blob/main/README.md#install),
[Features/Roadmap](https://github.com/jordanbaird/Ice/blob/main/README.md#featuresroadmap),
[Gallery](https://github.com/jordanbaird/Ice/blob/main/README.md#gallery), and
[License](https://github.com/jordanbaird/Ice/blob/main/README.md#license).

### BeardedSpice: media-routing vocabulary

BeardedSpice answers "What?" and "How?" before listing installation and
features. It explains that media keys control a selected supported target,
then documents automatic selection, configurable shortcuts, supported native
applications, and supported sites. Its contribution section points to a
specific developer guide for adding support. The same flow maps well to
SpotiBind: define forwarding in one sentence, show the three supported commands,
explain Automatic versus a fixed player, then link adapter and architecture
details rather than putting implementation internals in the opening paragraphs.

Source sections: [What?](https://github.com/beardedspice/beardedspice/blob/master/README.md#what),
[How?](https://github.com/beardedspice/beardedspice/blob/master/README.md#how),
[Features](https://github.com/beardedspice/beardedspice/blob/master/README.md#features),
[Supported Mac OS X applications](https://github.com/beardedspice/beardedspice/blob/master/README.md#supported-mac-os-x-applications),
and [Want to Contribute?](https://github.com/beardedspice/beardedspice/blob/master/README.md#want-to-contribute).

## Recommended SpotiBind README shape

Use English `README.md` as the canonical document and link the Chinese variant
near the title, for example `Chinese: [README.zh-CN.md](../README.zh-CN.md)`. The
Chinese file should preserve the same headings and factual content, but should
read naturally for Chinese users rather than being a literal line-by-line
translation.

Recommended order:

1. Product identity, one-sentence value proposition, language link, and a small
   set of useful badges or a release/download link.
2. A short feature list focused on routing the three hardware media keys,
   Automatic/player-specific/Off modes, supported players, menu-bar controls,
   and per-player path settings.
3. `Requirements`, including macOS 13+, the Accessibility permission, and the
   player-specific requirements. State clearly what SpotiBind does not require
   (admin/root, System Extension, Automation permission) only if it remains
   useful to onboarding.
4. `Install`, with the universal DMG from GitHub Releases, `/Applications`,
   first-launch behavior for the non-notarized Ad Hoc build, and a concise
   Accessibility setup instruction.
5. `Usage`, showing the normal path: choose Automatic or a player in the menu,
   press play/pause/next/previous, and use Advanced Settings for locations.
   Keep the player mapping table here, not in the feature pitch.
6. `Behavior and troubleshooting`, covering pass-through when forwarding is
   not ready, one-command-per-press, launch/wait behavior, and the visible
   failure path. Link to `docs/permissions.md` and `docs/architecture.md` for
   implementation-level detail.
7. `Build and test`, using the checked-in scripts and the actual Xcode/Icon
   Composer prerequisites. Link to `CONTRIBUTING.md` for contribution policy.
8. `Contributing`, with the expected test/build checks, adapter/support changes,
   issue/PR expectations, and a link to the contributor guide.
9. `License`, linking to `LICENSE` and stating MIT. Keep the independent-project
   disclaimer for third-party player names.

## Content and tone constraints

- Lead with the user outcome, not event-tap or PID implementation details.
- Say "hardware media keys" and "forward" consistently; reserve "intercept" for
  a behavior explanation where the distinction matters.
- Distinguish `Automatic`, a selected player, and `Off`; do not imply that an
  installed player is necessarily a usable running target.
- Make Accessibility a setup prerequisite and describe the exact macOS path,
  while avoiding alarmist language or unexplained permissions terminology.
- Keep the supported-player table factual: player, command mapping, and any
  player-specific install/version requirement. Link out to deeper docs when the
  table would become a compatibility matrix.
- Do not list GitHub or project URLs in product copy intended for the social
  preview; the README can provide normal repository and release links.
- Keep the opening scan-friendly. Detailed contracts already live in
  `docs/architecture.md`, `docs/permissions.md`, `docs/testing.md`, and
  `docs/release.md`.
