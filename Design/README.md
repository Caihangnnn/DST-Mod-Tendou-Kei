# 天童柯伊设计索引

状态：以当前代码和已确认讨论为准。除特别标明“规划”外，本文档均描述已实现或已固定的规则。

| 文件 | 内容 |
| --- | --- |
| `Kei_Initial_Design_Map.md` | 角色定位、三维、休眠与工程能力。 |
| `Kei_First_Version_Playable_Rules.md` | 初始数值、配方、配置和保存边界。 |
| `Kei_Extension_Protocol_Slots.md` | 协议槽、预设盒和协议运行规则。 |
| `Kei_Combat_Data_Recorder.md` | 战斗数据记录器与 Boss 记录流程。 |
| `Kei_Combat_Data_Protocols.md` | 全部战斗协议及其记录对象。 |
| `Kei_Analysis_Protocol.md` | 装备解析与虚拟装备适配。 |
| `Kei_Life_Protocols.md` | 可挂载生活协议。 |
| `Kei_Life_Data_Learning.md` | NPC 教材与生活学习路线规划。 |

## 当前总览

Kei 是以电量、数据稳定性和机体完整度运行的学习型机械角色。成长由三条可并存的路线构成：

- 战斗数据：通过数据记录器记录并击败指定 Boss，获得战斗协议。
- 装备解析：把装备转化为解析协议，复用装备或属性能力。
- 生活学习：NPC 教材与可挂载生活协议改善探索、成长和维护体验。

协议槽为统一挂载入口；战斗协议、解析协议和生活协议均可放入已解锁槽位。
