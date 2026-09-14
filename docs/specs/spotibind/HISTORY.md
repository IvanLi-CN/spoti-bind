# SpotiBind 媒体键转发主题历史

> 这里记录主题局部生命周期、替换、兼容性与必要背景；完整 ADR 取舍保留在 `docs/adr/`。单次任务流水账不放这里，规范正文仍以 `./SPEC.md` 为准。

## Lifecycle / Compatibility

- The topic is active and starts at the macOS 13.0 compatibility baseline.
- The product identity changed from Fastpotify Keys to SpotiBind before public
  distribution. The current bundle identifier is `cc.ivanli.spotibind`; the
  prior planned identifier has no released-user migration contract.

## Replacements / Background

- The topic records the original public event-capture and Fastpotify CLI boundary described by ADR-0001, then its multi-player successor in ADR-0008.
- Player Mode migration preserves `targetPath` as a Fastpotify-only override while replacing the old forwarding toggle with Automatic, four player modes, and Off.
- SwiftPM remains the single repository entrypoint for application code and
  tests. ADR-0010 adds a deliberately narrow Xcode/Icon Composer exception for
  native application icon resources and does not move business code into an
  Xcode target.
- SwiftPM is the single repository build entrypoint according to ADR-0006; Xcode remains an optional IDE.
- ADR-0009 replaces tag-triggered Draft Releases with a label-gated, identity-bound public Release after verified main merges. `VERSION` remains the only numeric source and `type:none` is the explicit no-release exception.
- The player launch boundary now exposes structured dispatch outcomes and a
  Finder recovery action for first-launch trust failures. Support claims use a
  pre-merge manual trust, close, cold-start, and single-key check; Gatekeeper
  approval remains a user action and is never bypassed.
- Queue timeout handling now returns each gesture's deadline result without
  allowing a queued operation to execute after its predecessor drains; the
  serial tail remains occupied until cancellation-insensitive side effects
  finish. The timeout signal is delivered independently of cooperative task
  scheduling so launch barriers and caller deadlines remain stable under
  runner load.

## Related Changes

- [PR #4](https://github.com/IvanLi-CN/spoti-bind/pull/4) delivers the modern
  menu-bar panel, retained Advanced Settings window, and target-scoped visual
  evidence. The PR intentionally stops at merge-ready and is not merged by
  this delivery flow.

## References

- `./SPEC.md`
- `./IMPLEMENTATION.md`
