# UI 改进计划

本文件记录针对 Arcmark UI 的改进建议清单，作为本分支（`codex/ui-improvements`）的工作依据。
每项任务完成后会标注 ✅，并记录实施要点与测试结论。

---

## 工作流程

1. 每做一项前，先出非代码方案给作者确认。
2. 实施完成后，提示作者测试。
3. 作者确认 OK 后，在本文档末尾的「进度记录」补一条，并在 TODO 清单中标注完成。

## 任务清单（按优先级顺序实施）

### 1. 深色模式支持（颜色系统）

**现状**
- `ThemeConstants.Colors` 仅 3 个硬编码浅色值（`darkGray`、`white`、`settingsBackground`）。
- `MainViewController.applyWorkspaceStyling()` 已被简化成永远使用 `.settingsBackground`，8 种 workspace 颜色未真正生效。
- `NodeRowView`、`SearchBarView` 等组件引用这些常量后无法跟随系统 appearance。

**目标**
- 让 `ThemeConstants.Colors` 关键颜色成为动态色（`NSColor(name:)`），跟随系统浅深色切换。
- 让 `WorkspaceColorId` 的 8 种颜色真正参与 workspace 主题（至少在浅色下生效，深色下做适配）。
- 保持当前 `.settingsBackground` 行为作为默认 fallback，避免一次改动破坏面过大。

**非目标**
- 不重写整个色彩系统，仅让"颜色"变成 dynamic，沿用现有引用点。
- 不引入第三方主题库。

### 2. Favicon 占位符 / 首字母圆形图标

**现状**
- `NodeRowView.iconView` 在 favicon 为 nil 时为空，首屏会有一批空白图标直到 favicon 加载完。
- favicon 失败时没有视觉 fallback。

**目标**
- 为 link 类节点提供「域名首字母 + workspace 颜色」的圆形占位符图标。
- 仅作为视觉占位，favicon 加载成功后照常替换。
- 抽一个 `PlaceholderIconGenerator`（或类似）做生成，避免散落。

**非目标**
- 不改 favicon 缓存策略或抓取逻辑。

### 3. 列表键盘导航

**现状**
- 仅有 `⌘⌥←/→` 切 workspace 的快捷键（在 `AppDelegate.setupMenus`）。
- node 列表内 `↑/↓` 移动选择、`Enter` 打开/重命名、`⌫` 删除等均缺失。

**目标**
- 在 `NodeListViewController`（或 `MainViewController`）增加列表键盘导航：
  - `↑/↓` 在可见 node 间移动 selection（自动展开折叠？先不自动展开，仅可见项导航）。
  - `Enter` 打开 link；`⌘R` 或 `F2` 重命名。
  - `⌘⌫` 删除（带确认？先不加确认，靠 #4 的 undo 兜底）。
  - `Esc` 清除选中 / 退出搜索。
- 搜索激活时优先响应搜索框自身键位。

**非目标**
- 不实现 Quick Look 式预览（Space）。

### 4. 删除 Undo（NSUndoManager）

**现状**
- `deleteWorkspaceFromMenu`、`model.deleteNode` 等破坏性操作无撤销。
- AppKit 自带 Edit 菜单有 Undo/Redo 项，但目前未接线。

**目标**
- 接入 `NSUndoManager`，至少覆盖：
  - 删除 workspace
  - 删除 node（含 folder 子树）
- Undo/Redo 通过窗口的 undo manager 生效，`⌘Z` / `⌘⇧Z` 可用。
- 重命名、移动等暂不强制接入。

**非目标**
- 不做完整命令模式（Command pattern），仅对破坏性删除做 undo。

### 5. 空搜索状态视图

**现状**
- `SearchCoordinator` 过滤后无结果时，列表区域直接空白。

**目标**
- 当搜索激活且结果为空时，在列表区域显示空状态：
  - 一个 SF Symbol（如 `magnifyingglass` 或 `tray`）。
  - 文案：`No results for "xxx"`。
  - 「Clear」按钮调用 `searchField` 清空。
- 空状态与正常列表互斥显示。

**非目标**
- 不做"建议搜索词"之类的高级功能。

### 6. 收敛残留 magic numbers 到 ThemeConstants

**现状**
- `ThemeConstants` 是单一来源，但仍有硬编码散落：
  - `NodeRowView` 的 `iconLeading: 16`、`icon size: 26`、各种 `-16`、`22`。
  - `MainViewController` 的 `topBar.heightAnchor: 30`、`popoverContentSize 280×320`。
  - `AppDelegate` 的 `contentRect 340×680`、`minSize 280×420`。

**目标**
- 在 `ThemeConstants`（必要时新建 `WindowConstants` 子结构）补齐这些常量。
- 替换引用点，保持视觉完全不变。

**非目标**
- 不强制「0 magic number」，仅清理明显可复用的尺寸/间距。

---

## 进度记录

（每完成一项，在此追加一行：日期 / 任务 / 结论）
