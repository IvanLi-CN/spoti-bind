# 规格（Spec）总览

本目录是 topic-level specification catalog：每个 spec 对应一个稳定主题、能力、接口或约束的长期契约，不是单次任务的进度卡片。

每个新 spec 目录默认包含：

- `SPEC.md`：当前有效规范 / 主题契约；`## Related ADRs` 列出当前关联 ADR，或写 `None`
- `IMPLEMENTATION.md`：实现覆盖、当前状态、剩余缺口与 rollout 事实
- `HISTORY.md`：主题局部生命周期、替换、兼容性与必要背景；不复制 ADR 的完整取舍理由

## Index

| Topic | Lifecycle | Implementation | Spec | Successor | Notes |
| --- | --- | --- | --- | --- | --- |
| SpotiBind media forwarding | active | 初始化中 | `spotibind/SPEC.md` | - | 固定媒体键路由与 Ad Hoc 分发边界 |
