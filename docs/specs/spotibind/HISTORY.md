# SpotiBind 媒体键转发主题历史

> 这里记录主题局部生命周期、替换、兼容性与必要背景；完整 ADR 取舍保留在 `docs/adr/`。单次任务流水账不放这里，规范正文仍以 `./SPEC.md` 为准。

## Lifecycle / Compatibility

- The topic is active and starts at the macOS 13.0 compatibility baseline.
- The product identity changed from Fastpotify Keys to SpotiBind before public
  distribution. The current bundle identifier is `cc.ivanli.spotibind`; the
  prior planned identifier has no released-user migration contract.

## Replacements / Background

- The topic records the original public event-capture and Fastpotify CLI boundary described by ADR-0001, then its multi-player successor in ADR-0008.
- Player Mode migration preserves `targetPath` as a Fastpotify-only override while replacing the old forwarding toggle with Automatic, three player modes, and Off.
- SwiftPM is the single repository build entrypoint according to ADR-0006; Xcode remains an optional IDE.

## Related Changes

- [PR #4](https://github.com/IvanLi-CN/spoti-bind/pull/4) delivers the modern
  menu-bar panel, retained Advanced Settings window, and target-scoped visual
  evidence. The PR intentionally stops at merge-ready and is not merged by
  this delivery flow.

## References

- `./SPEC.md`
- `./IMPLEMENTATION.md`
