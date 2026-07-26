# CH0335 Experience Halo

这是基于 `CH0335_Halo.png` 制作的 Spriter SCML 状态图标。

## 动画状态

- `exp_unfilled`：经验值未达到当前上限，冷紫色低亮状态。
- `exp_full`：经验值达到当前上限，明亮粉色状态。

两个状态各有两个关键帧，在 800 ms 内做轻微亮度脉动并循环播放。当前经验值数字不写入 SCML，应由人物状态区在图标右侧叠加文本，以便动态更新。

## 使用方式

将 `CH0335_Experience_Halo.scml` 及同名图片目录保持相对位置不变。加载后使用实体 `CH0335_Experience_Halo`，根据经验值播放 `exp_unfilled` 或 `exp_full`。

图标以裁切后的 1171×1047 透明 PNG 保存，中心 pivot 为 0.5/0.5，便于在 `UIAnim` 中统一缩放和定位。
