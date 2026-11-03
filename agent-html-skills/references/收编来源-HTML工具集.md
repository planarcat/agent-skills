# 收编来源与许可（SOURCES）

本目录收编自社区，仅作本技能的**内部参考资料**（不作为独立技能发现）。上游更新需手动同步。

| 内容 | 上游 | 版本 / commit | 收编日期 | 许可 |
|---|---|---|---|---|
| `skills/`（19 个子技能） | https://github.com/f-labs-io/agent-html-skills | main @ `a9ddeb2`（`plugins/html-skills/skills/`） | 2026-10-31 | MIT |
| `assets/`（blocks 模板 + submit-handler.js，共享件） | 同上（`plugins/html-skills/assets/`） | 同上 | 2026-10-31 | MIT |
| `upstream-README.md` | 同上（`plugins/html-skills/README.md`） | 同上 | 2026-10-31 | MIT |

上游 LICENSE 随 `references/LICENSE` 收编。`html-skills-listen/server.js`、`scripts/listen.sh`、`assets/submit-handler.js` 为第三方可执行代码，首次运行前应通读确认。
