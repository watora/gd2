# GD2 开发协作指南

本项目是一个 Godot 4.6 2D 游戏，题材方向为“模拟经营 + 地下城探索”，美术方向为日本动漫风格。第一阶段目标是借助 Godot MCP 快速生成一个具有可行玩法闭环的 demo，素材先使用简单占位图，后续逐步替换和迭代。

## 项目目标

- 核心体验：玩家在经营据点中准备资源、招募或培养角色，然后进入地下城探索、战斗、收集材料，再回到据点扩张经营。
- 第一阶段 demo 只追求可玩闭环，不追求最终美术质量。
- 优先实现明确、可测试、可迭代的系统边界，避免过早做复杂框架。
- 所有新增玩法应能在 Godot 编辑器中直观看到，并尽量通过 Inspector 调整关键参数。

## 当前项目结构

```text
res://
  project.godot              Godot 项目配置。不要直接手写修改，使用编辑器或 MCP 项目设置工具。
  node_2d.tscn               当前默认测试场景，后续应迁移或替换为正式入口场景。
  icon.svg                   Godot 默认图标。
  Assets/
    bg/                      现有背景素材目录。
  addons/
    godot_mcp/               Godot MCP 插件。除非在维护插件本身，否则不要改动。
```

## 目标项目结构

后续开发优先按以下结构新增文件。当前已有 `Assets/` 可暂时保留；新建资源目录时优先使用小写目录名，避免大小写路径混用。

```text
res://
  scenes/
    main/                    游戏入口、主流程、全局场景。
    management/              据点经营、建筑、生产、角色整备相关场景。
    dungeon/                 地下城地图、房间、遭遇、探索相关场景。
    battle/                  战斗场景、敌人编队、技能表现相关场景。
    ui/                      可复用 UI 场景，如面板、按钮组、提示框。
  scripts/
    core/                    游戏状态、存档、事件总线、通用工具。
    management/              经营玩法逻辑。
    dungeon/                 地下城探索逻辑。
    battle/                  战斗逻辑。
    ui/                      UI 控制脚本。
  assets/
    characters/              角色立绘、头像、占位角色图。
    enemies/                 敌人图像和动画。
    bg/                      背景图。
    tiles/                   TileSet、TileMap 贴图。
    ui/                      UI 图标、按钮、边框、面板纹理。
    audio/                   音效和音乐。
  resources/
    characters/              CharacterData、职业、成长曲线等 Resource。
    enemies/                 EnemyData、掉落表等 Resource。
    items/                   道具、装备、材料 Resource。
    dungeon/                 地下城配置、房间池、遭遇表。
  data/
    balance/                 平衡表、CSV 或 JSON 配置。
    localization/            本地化文本。
  tests/
    unit/                    纯逻辑测试。
    scenes/                  场景级 smoke test 或测试场景。
  docs/
    design/                  玩法设计、系统说明、迭代记录。
```

## 第一阶段 Demo 范围

第一阶段应先完成以下最小闭环：

1. 主入口场景：进入据点经营界面。
2. 据点经营：显示金币、材料、角色状态，提供至少一个可升级设施或生产按钮。
3. 地下城探索：进入一个简化地下城，包含移动、房间切换、敌人遭遇或资源采集。
4. 战斗或事件：实现一个简单回合制战斗、自动战斗或事件判定。
5. 结算回流：地下城结束后把奖励带回据点，能继续升级或再次探索。

占位素材要求：

- 可以使用简单生成图、纯色块、基础图标或临时动漫风格头像。
- 占位资源文件名必须带 `_placeholder` 后缀。
- 不要把临时素材写死到核心逻辑中，资源路径应从导出变量、Resource 或配置中传入。

## Godot MCP 使用约定

- 构建场景时优先使用 MCP 编辑器工具：创建场景、添加节点、设置 Inspector 属性、保存场景。
- 运行期检查或输入模拟前必须先启动场景；运行期工具只能在 `play_scene` 之后使用。
- 修改 `project.godot` 设置时使用 MCP 项目设置工具或 Godot 编辑器，不要直接编辑该文件。
- 场景可视属性优先放在 Inspector 中，例如位置、颜色、尺寸、纹理、主题覆盖等。
- 只有运行时动态行为、复杂计算、状态切换才写入 GDScript。
- 每次用 MCP 生成或修改关键场景后，应保存场景并做一次运行检查。

## GDScript 代码风格

- 使用 Godot 4.x GDScript。
- 脚本文件使用 `snake_case.gd`，例如 `dungeon_controller.gd`。
- 类名使用 `PascalCase`，例如 `class_name DungeonController`。
- 变量、函数、信号使用 `snake_case`。
- 常量使用 `UPPER_SNAKE_CASE`。
- 节点路径缓存使用 `@onready var`。
- 可调参数使用 `@export` 暴露到 Inspector。
- 公共数据优先用 `Resource` 表达，避免散落的硬编码字典。
- 复杂节点引用优先通过导出 `NodePath` 或明确的子节点结构，不要依赖脆弱的深层字符串路径。
- 函数应短小，单个函数只处理一个明确动作。
- 不在 `_process()` 中做不必要的全局搜索、资源加载或大量分配。

示例：

```gdscript
class_name DungeonRunController
extends Node

signal run_finished(rewards: Dictionary)

const MAX_ROOM_COUNT := 8

@export var starting_room_count := 3
@export var reward_table: Resource

@onready var room_label: Label = %RoomLabel

var current_room_index := 0

func start_run() -> void:
	current_room_index = 0
	_update_room_label()

func advance_room() -> void:
	current_room_index += 1
	_update_room_label()

func _update_room_label() -> void:
	room_label.text = "%d / %d" % [current_room_index + 1, starting_room_count]
```

## 场景与节点约定

- 场景文件使用 `snake_case.tscn`。
- 可复用场景根节点命名使用 `PascalCase`，例如 `ManagementScreen`、`DungeonRoomView`。
- UI 场景根节点优先使用合适的 `Control` 派生类。
- 2D 游戏对象优先使用 `Node2D`、`CharacterBody2D`、`Area2D`、`Sprite2D`、`AnimatedSprite2D`。
- UI 布局优先使用容器节点，不手写绝对位置堆 UI。
- 关键节点使用唯一名称 `%NodeName`，但不要滥用唯一名称。
- 场景之间通过明确的 API、信号或全局状态服务通信，避免跨场景随意查找节点。

## 资源命名约定

通用格式：

```text
<domain>_<object>_<variant>.<ext>
```

示例：

```text
char_aki_portrait_placeholder.png
enemy_slime_idle_placeholder.png
bg_dungeon_corridor_placeholder.png
ui_icon_gold_placeholder.png
item_iron_ore.tres
dungeon_forest_ruins_room_pool.tres
```

约定：

- 文件和目录使用小写 `snake_case`。
- 占位图使用 `_placeholder` 后缀。
- 角色资源前缀使用 `char_`。
- 敌人资源前缀使用 `enemy_`。
- UI 资源前缀使用 `ui_`。
- 背景资源前缀使用 `bg_`。
- 道具资源前缀使用 `item_`。
- 地下城配置前缀使用 `dungeon_`。
- Godot `.import` 文件由引擎生成，不手动编辑。

## Resource 与数据约定

- 角色、敌人、道具、设施、地下城房间等可配置内容优先建为 `.tres` Resource。
- 需要表格化批量调整的数据可以放入 `data/balance/`，但运行时应有清晰的加载入口。
- 不把平衡数值散落在 UI 脚本中。
- 数据 Resource 中只存配置，不直接持有运行时状态。
- 运行时状态放在专门的状态对象、控制器或存档结构中。

## UI 与交互约定

- 第一阶段 UI 以清晰可用为主，不做复杂动效。
- 经营界面应始终显示核心资源：金币、材料、队伍状态。
- 地下城界面应始终显示当前位置、生命或队伍状态、可执行操作。
- 按钮文案使用动词开头，例如“开始探索”“升级工坊”“返回据点”。
- UI 逻辑脚本只负责展示和输入转发，核心玩法计算放到对应系统脚本中。

## 美术方向

- 长期目标是日本动漫风格：清晰轮廓、干净色块、明亮但不过饱和的配色、角色辨识度优先。
- demo 占位图保持统一比例和命名，便于后续替换。
- 角色头像建议先统一为方形或 4:5 比例。
- 地下城背景和房间图建议先统一 16:9 或项目实际视口比例。
- 不同来源的临时素材应记录在 `docs/design/art_sources.md`，避免后续版权和替换成本不清。

## 测试与验证

- 新增核心逻辑后，至少运行对应场景做一次 smoke test。
- 修改 UI 后，检查桌面窗口下文字不重叠、按钮可点击、状态数值会刷新。
- 修改地下城或战斗循环后，验证一次完整流程：据点 -> 地下城 -> 结算 -> 据点。
- 修复 bug 时优先补一个能复现问题的最小测试或测试场景。

## 开发注意事项

- 不要改动 `addons/godot_mcp/`，除非任务明确要求维护 MCP 插件。
- 不要直接编辑 `project.godot`。
- 不要提交 `.godot/` 缓存目录。
- 不要把临时调试节点、测试按钮、硬编码奖励留在正式场景中，除非明确标注为 demo-only。
- 不要在一个脚本里混合经营、地下城、战斗和 UI 展示逻辑。
- 任何新增系统都应先满足第一阶段 demo 的可玩闭环，再考虑扩展性。
