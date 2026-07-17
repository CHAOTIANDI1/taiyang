# 03 - 数据驱动架构与 JSON 工作原理

## 概念

"数据驱动" = 把游戏里的数字（血量、攻击、配方）放在外面的 JSON 文件里，代码只管读取，不管记住。

## 功能

调数值不动代码。改一下怪物血量、增一个食谱，只改数据文件，游戏自动生效。

## 运作方式（举例）

### 传统方式（反例）

硬编码血量在代码里：
```gdscript
# scripts/combat.gd
func get_monster_hp(name):
    if name == "红尾蝎":
        return 50
    elif name == "暗影法师":
        return 80
    elif name == "Boss":
        return 1000
```

问题：
- 每加一种怪要改代码
- 改数值要重新运行游戏
- AI 修改时容易误伤其他代码

### 数据驱动方式（正例）

把血量放 `data/monsters.json`：
```json
{
  "red_scorpion": { "name": "红尾蝎", "hp": 50, "damage": 12 },
  "shadow_mage": { "name": "暗影法师", "hp": 80, "damage": 20 },
  "boss_01":      { "name": "暗影侵蚀者", "hp": 1000, "damage": 30 }
}
```

代码只管读：
```gdscript
# scripts/core/data_manager.gd
var monsters = load_json("data/monsters.json")

func get_monster_hp(id):
    return monsters[id]["hp"]
```

调用时：
```gdscript
# scripts/combat.gd
var hp = DataManager.get_monster_hp("red_scorpion")  # 拿到 50
```

### 关键点：扣血怎么算

代码只算"减法"，不算"具体数字"：
```gdscript
# scripts/combat.gd
func take_damage(amount):
    current_hp -= amount          # 减法
    if current_hp <= 0:
        die()                     # 死亡
```

血量数字本身从 JSON 来，"扣 12 点"还是"扣 50 点"都是配置，不是代码逻辑。

## 原理

核心原理是"**拆分数值和算法**"：
- **数值**（变的部分）= JSON：怪物血量、技能伤害、等待时长
- **算法**（不变的部分）= 代码：怎么扣血、怎么判定死亡、怎么播动画

代码是固定管道，数值从管道流入流过。换数值 = 换水，不动管道。

## 优势

| 优势 | 说明 |
|------|------|
| 调数值灵活 | 改 JSON 一个数字游戏就生效 |
| 加新内容快 | JSON 加一行就加一个新怪物 |
| 减少代码量 | 不用每个怪物写一段 if 判断 |
| 防止误伤 | 改数值不会动到战斗算法代码 |
| 利于联机 | 服务端和客户端共享同一套 JSON |
| 利于验证 | 数值变化可追溯（Git 显示哪行改了） |

## 使用场景

### 场景：你想让红尾蝎变强

**步骤**：
1. 用 VS Code 打开 `D:\taiyang\data\monsters.json`
2. 找到 `"red_scorpion"` 那一节
3. 把 `"hp": 50` 改成 `"hp": 80`，`"damage": 12` 改成 `"damage": 20`
4. 保存
5. 重启 Godot（或重新加载场景）
6. 红尾蝎就变强了，**没碰一行代码**

### 场景：加一个新怪物

1. 在 `monsters.json` 末尾加一段：
```json
"ice_slime": { "name": "冰史莱姆", "hp": 30, "damage": 8, "ai_template": "melee_charger" }
```
2. 在 `data/items.json` 注册它掉落的物品
3. 在美术资源里给它画个素材
4. 启动游戏 → 冰史莱姆就出现在系统里（哪里刷怪需要另外安排）

整个过程没改代码——"添加新怪"完全靠数据。

## 在我们项目的角色

我们 15 个 JSON 文件就是数据驱动的具体落地：
- `monsters.json`：怪物
- `items.json`：物品
- `equipment.json`：装备
- `skills.json`：技能
- `recipes.json`：食谱
- ...等

代码（DataManager 单例）只负责"读和返回"，不存数字。

---

## 关联

- 怎么让代码不直接改血条：[[04-逻辑与显示分离原理]]
- DataManager 这种单例怎么工作：[[06-单例模式与Autoload]]
- 数据改了怎么不忘改文档：[[08-三项一致原则]]