# 天童 柯伊 Tendou Kei

这是一个《饥荒：联机版》角色 Mod。入口文件只负责建立 Mod 环境、声明预制体并按顺序加载启动模块；具体功能按领域放在 `scripts/` 下维护。

## 目录结构

- `scripts/kei/`: Kei 的业务模块、协议定义、成长系统、无人机系统和跨 Mod 集成。
- `scripts/kei/hooks/`: 通用组件、实体、网络和 UI 钩子。
- `scripts/kei/drone/hooks/`: 仅服务于旋翼调查仪系统的钩子。
- `scripts/components/`: 服务端组件及其数据持久化逻辑。
- `scripts/prefabs/`: 角色、物品、特效、Boss 和建筑预制体。
- `scripts/stategraphs/`、`scripts/brains/`: 状态图和 AI。
- `scripts/widgets/`、`scripts/screens/`: 客户端界面。
- `anim/`、`images/`、`bigportraits/`: Mod 资源。

## 启动顺序

`modmain.lua` 使用以下顺序初始化：

1. `scripts/kei/assets.lua` 声明资源和小地图图集。
2. `scripts/kei/config.lua` 读取配置并填充 `TUNING`。
3. `scripts/kei/hooks/init.lua` 注册通用 hooks。
4. `scripts/kei/init.lua` 注册动作、配方、无人机、集成和成长系统。
5. `scripts/prefabs/kei__all_prefabs.lua` 按分类清单聚合预制体。

新增模块时，优先放入对应领域目录，并在该领域的 `init.lua` 或清单中登记。需要依赖另一个模块的注册逻辑时，应把被依赖模块放在前面，并在加载列表旁留下简短说明。

## 静态检查

本地安装 Lua 5.1 后，可使用以下命令检查全部 Lua 文件的语法：

```powershell
& 'D:\Application\lua\5.1\luac.exe' -p (rg --files -g '*.lua')
```
