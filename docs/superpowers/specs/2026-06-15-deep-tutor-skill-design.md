# Deep Tutor Skill — Design Spec

**Date:** 2026-06-15
**Author:** brainstorming session (King-Wood-Shen + Claude Opus 4.7)
**Repo:** [King-Wood-Shen/deep-tutor-skill](https://github.com/King-Wood-Shen/deep-tutor-skill)
**License:** Apache 2.0
**Status:** Draft for review

## 0 · 背景与目标

把 [HKUDS/DeepTutor](https://github.com/HKUDS/DeepTutor) 中最有"教学灵魂"的两块——**Deep Tutor**（Socratic 教学 / 出题 / 学习路径）与 **Deep Research**（带引用的研究报告）——浓缩成一对 Claude Code skill。研究侧融合一篇小红书帖子的方法论：**"代码 > 论文文本，要让 AI 通过实现去找反直觉的 novel ideas，而不是靠论文摘要"**。

**显式排除（v1 不做）：** IM Partner、Co-Writer / Living Book HTML、多用户/auth、本地向量 RAG、L1/L2/L3 三层记忆基础设施。

## 1 · 架构与边界

### 1.1 两个 skill，main + aux

| skill | 角色 | 触发 |
|---|---|---|
| `deep-tutor` | 主 skill。识别输入、判定模式、跑教学循环、管工作区、按需调 `deep-research`。 | 用户直接调用 |
| `deep-research` | 辅 skill。被主 skill 通过 Skill 工具调用；用户也可直接调用。code-first 研究。 | 主 skill 调用 / 用户直接 |

### 1.2 拆两个的理由

- `deep-research` 独立有价值（用户可能只想做研究）
- 单个 SKILL.md 越短，模型遵循度越高
- 对齐 DeepTutor 模块化 runtime 哲学

### 1.3 文件结构

```
~/.claude/skills/
├── deep-tutor/
│   ├── SKILL.md
│   ├── references/
│   │   ├── input-detection.md
│   │   ├── light-mode.md
│   │   ├── heavy-mode.md
│   │   ├── workspace-spec.md
│   │   └── socratic-prompts.md
│   └── scripts/
│       └── init_workspace.sh
└── deep-research/
    ├── SKILL.md
    ├── references/
    │   ├── xhs-methodology.md
    │   ├── citation-rules.md
    │   └── execute-tier.md
    └── scripts/
```

### 1.4 互调

`deep-tutor` → `deep-research`：通过 Skill 工具，传 topic / workspace / sources / mode / question / execute_tier 参数。两 skill 共享 cwd 下的 `.deeptutor/<topic>/` 工作区。

## 2 · 工作区结构与数据流

### 2.1 落点

工作区开在用户当前 cwd 下，每个主题一个目录：

```
<cwd>/.deeptutor/
└── <topic-slug>/
    ├── manifest.yaml
    ├── learning_log.md
    ├── findings.md
    ├── research_report.md
    ├── quizzes.md
    ├── learning_path.md
    └── sources/
        ├── papers/
        ├── code/
        └── web/
```

### 2.2 文件职责

| 文件 | 写者 | 读时机 | 关键字段/段落 |
|---|---|---|---|
| `manifest.yaml` | 主 skill 启动时写一次，按需更新 | 每次进入工作区先读 | `topic`, `entry_mode`, `current_mode`, `sources[]`, `created_at`, `updated_at` |
| `learning_log.md` | 主 skill 每轮教学后追加 | 续会话时读最近 N 段 | 时间戳分节；`Concept` / `User understanding` / `Gaps` |
| `findings.md` | `deep-research` 写，主 skill 引用/勾选 | 教学和研究都读 | `💡 反直觉点` / `🐛 潜在 Bug/实现问题` / `🧪 待跑实验` 三类列表 |
| `research_report.md` | `deep-research` 写 | 用户问研究结论时读 | 标准结构：背景 / 方法 / 关键发现 / 引用列表 |
| `quizzes.md` | 主 skill 写 | 间隔重复出题时读 | 每题：题干、参考答案、用户上次答案、对错、上次时间 |
| `learning_path.md` | 主 skill intake 后写一次，进度持续更新 | 每轮前读 | DAG（缩进 markdown 列表 + `[x]/[ ]/[~]` 状态） |
| `sources/*` | `deep-research` 写 | 写报告/findings 引用 | 文件名带索引和短哈希便于交叉引用 |

### 2.3 数据流（一轮交互）

```
用户消息
   │
   ▼
[deep-tutor]
   │── 读 manifest.yaml（或创建工作区）
   │── 读 learning_log 最近段 + learning_path 进度
   │── 按 current_mode 走 light / heavy
   │
   ├── (需要研究?) ──► Skill 调 deep-research
   │                        │── 读 manifest 知上下文
   │                        │── 抓 paper / repo / web
   │                        │── 写 sources/, findings.md, research_report.md
   │                        └── 返回结构化 summary
   │
   │── 生成本轮回复（讲解 / 追问 / 出题 / 引用 findings）
   │── 追加 learning_log；更新 quizzes / learning_path
   ▼
用户下一条
```

### 2.4 Topic-slug 规则

主 skill 在首条消息**猜 slug**（kebab-case，6 词内），存进 `manifest.yaml`。同 cwd 同 slug → 续会话。用户可显式"新建主题 X" / "继续主题 Y" 覆盖。

### 2.5 跨主题 / 跨 cwd

v1 不做全局知识库。同 cwd 多主题平铺。跨主题引用 = `manifest.yaml.related[]` 手填路径。

## 3 · 输入识别 & 模式分流

### 3.1 判定流程（主 SKILL.md 内写死）

```
首条消息
   │
   ▼
①扫资源
   ├ arXiv URL / PDF 路径   → entry = paper
   ├ github.com / *.git     → entry = repo
   ├ 本地可读目录路径       → entry = local_code
   └ 纯文字                 → entry = topic
   │
   ▼
②扫意图词
   ├ "novel" / "改进" / "复现" / "找 bug" / "研究" / "review" → intent = research
   ├ "搞懂" / "学" / "理解" / "教我"                             → intent = learn
   └ 都没有 → entry=repo/local_code 默认 research；其它默认 learn
   │
   ▼
③模式
   intent=research                            → heavy
   intent=learn, entry=paper/topic            → light
   intent=learn, entry=repo/local_code        → heavy（代码场景无轻量）
```

判定写进 `manifest.yaml.entry_mode` / `.current_mode`。用户可手动覆盖（"切轻量"/"切研究"）。

### 3.2 入口 → 行为表

| Entry | Intent | Mode | 首轮 |
|---|---|---|---|
| paper | learn | light | 抓 paper 摘要 → 概念地图 → Socratic |
| paper | research | heavy | 抓 paper + 找 repo → deep-research 全套 |
| repo | learn | heavy | deep-research 跑结构扫描 → learning_path → 边学边过代码 |
| repo | research | heavy | deep-research 全套（XHS 拉满） |
| local_code | * | heavy | Read/Grep 本地 → deep-research（跳过 clone） |
| topic | learn | light | Socratic + 必要时 deep-research 补背景 |
| topic | research | heavy | deep-research 主题扫荡 → 回主 skill |

## 4 · 两种模式

### 4.1 Light Mode

```
loop:
  1. 读 manifest + learning_log 最近 3 段 + learning_path 当前节点
  2. 决定动作：
       a) 讲解未掌握知识点
       b) Socratic 追问
       c) 出 1-2 题
       d) 局部调 deep-research 填窟窿
  3. 回复用户
  4. 追加 learning_log，更新 learning_path
```

不主动跑全套研究。deep-research 只填具体窟窿。

### 4.2 Heavy Mode

```
phase 0  intake（首次）:
  - 调 deep-research：扫 paper + repo + 抓 source → 写 sources/, findings.md, learning_path.md
  - 给用户 intake 摘要

phase 1  教学/研究混合循环:
  loop:
    1. 读 manifest + log + findings 未勾选项
    2. 决定动作：
         a) 讲 learning_path 下一节点
         b) 把 findings 拿来跟用户讨论
         c) 出题（题面来自 findings）
         d) 用户要"真跑实验" → 进 execute-tier
         e) 信息不够 → 增量调 deep-research
    3. 回复
    4. 追加 log；更新 findings 勾选；必要时改 learning_path
```

首次重，后续轻。XHS 方法论是 heavy mode 的核心。

## 5 · `deep-research` 子 skill 规范

### 5.1 调用契约

主 skill 传入：

```json
{
  "topic": "attention-mechanism",
  "workspace": ".deeptutor/attention-mechanism/",
  "sources": [
    {"type": "paper", "url": "https://arxiv.org/abs/1706.03762"},
    {"type": "repo",  "url": "https://github.com/tensorflow/tensor2tensor"}
  ],
  "mode": "intake | incremental",
  "question": "（可选）",
  "execute_tier": false
}
```

返回（给主 skill 读，不直接给用户）：

```json
{
  "wrote": ["sources/papers/attn_p1.md", "findings.md"],
  "new_findings": 5,
  "open_questions": ["..."],
  "needs_user_input": null
}
```

### 5.2 `xhs-methodology.md`（子 skill 灵魂）

> **优先级：代码 > 论文文本。**
> 1. 抓到 paper，**第一动作找配套 repo**（README / paper 末尾 / PapersWithCode / `gh search`）。无 repo 的 paper 价值减半，findings 标 `[no-code]`。
> 2. 对 repo 做**实现 vs 论文公式对齐扫描**：论文"假装很干净"但代码"有 magic constant / hard-coded scale / numerical stabilizer"的地方 → 挂"💡 反直觉点"。
> 3. 主动找 **bug / 改进点**：off-by-one、未 normalize 项、初始化隐含假设、注释/代码不一致 → 挂"🐛 潜在 Bug"。
> 4. 每个反直觉点配一个**可跑消融**："把 X 改成 Y，预期看到 Z" → 挂"🧪 待跑实验"。
> 5. **严禁只读 paper 写报告**。只有 paper 没 code，报告顶部标 **"⚠️ Paper-only — confidence reduced"**。

### 5.3 Execute Tier（opt-in）

仅当 `execute_tier: true`：

1. `gh repo clone` → `.deeptutor/<topic>/sources/code/_repo/`
2. 读 README / requirements / pyproject
3. **不自动 pip install**：先写 `setup_notes.md`，用户确认才装
4. 跑最小 smoke test（若 repo 有），日志存 `sources/code/_runs/<timestamp>.log`
5. 失败立即停，写诊断到 findings 的"🐛"，不重试

### 5.4 引用格式

- Paper: `[Vaswani et al. 2017](sources/papers/attn_p1.md) §3.2`
- Code: `[tensor2tensor/attn.py:142-158](sources/code/attn_p1.md)`（行号必须）
- Web: `[Title](sources/web/xxx.md) (accessed 2026-06-15)`

## 6 · 工具、错误处理、开发流程

### 6.1 工具

| Skill | 工具 |
|---|---|
| `deep-tutor` | Read, Write, Edit, Grep, Glob, Skill, Bash（轻量 git/ls） |
| `deep-research` | Read, Write, Grep, Glob, WebFetch, WebSearch, Bash（git clone / 可选 execute） |

### 6.2 错误/边界

| 场景 | 处理 |
|---|---|
| arXiv 抓不到 | 降级让用户贴正文，标 `[fetch-failed]` |
| Repo 私有/404 | 终止 research，回主 skill 让用户确认 |
| 只有 PDF | Read 工具读 PDF，分块抓关键段 |
| Repo >200MB | 不 clone，用 `gh api` 拉文件树 + `gh search code` 定点读 |
| 用户切主题 | 关当前工作区，按新 topic 走 §3 |
| Execute tier 卡环境 | 一次失败即停，写 setup_notes，不重试 |
| 用户说"忘了我"/"重新开始" | 移工作区到 `.deeptutor/_archive/<topic>-<ts>/`，新建 |

### 6.3 开发流程：10 轮 benchmark 驱动迭代

每个开发轮次：

```
Round N:
  1. 主线程做本轮开发（写/改 SKILL.md / references / scripts）
  2. commit
  3. spawn 新 Agent（独立上下文）作为 benchmark agent
       任务：在 benchmark/ 下扩充 cases，跑当前 skill 状态，输出 round_N_report.md
       输入：当前 skill 文件 + round_(N-1)_report.md
       产出：新测试用例、跑分、失败模式清单、改进建议
  4. 主线程读 round_N_report.md 决定下一轮
  5. 未到 10 轮 → Round N+1

Stop: 10 轮跑完 / 用户叫停 / 通过率 ≥ §6.4 阈值（80%）且连续 2 轮无回退
```

仓库结构（关键部分）：

```
deep-tutor-skill/
├── skills/
│   ├── deep-tutor/
│   └── deep-research/
├── benchmark/
│   ├── cases/        # 每个 case 一个 md：input + expected behaviors
│   ├── runners/      # spawn agent + 评分脚本
│   ├── reports/      # round_1_report.md … round_10_report.md
│   └── README.md
├── docs/superpowers/specs/2026-06-15-deep-tutor-skill-design.md
├── LICENSE
└── README.md
```

### 6.4 验收标准（v1）

- 4 种入口场景每种 ≥ 2 个 benchmark case 通过
- XHS 方法论：每个 heavy mode case ≥ 3 个 findings（反直觉/bug/实验各 ≥ 1）
- 工作区持久化：同主题第二次进入正确续接
- Execute tier opt-in 行为正确（默认不跑、显式才跑、失败不死循环）
- 10 轮 benchmark 跑完，最后一轮通过率 ≥ 上一轮且 ≥ 80%
