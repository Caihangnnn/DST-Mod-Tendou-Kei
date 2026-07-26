# CH0335 Experience Halo, 2-texture version

这是给 DST MOD TOOL 使用的版本。它只包含两张纹理图，避免导出时生成超过两个 atlas 纹理页：

- `exp_unfilled`：经验未达到当前上限。
- `exp_full`：经验达到当前上限。

每个状态使用同一张纹理图，通过 SCML 的缩放关键帧做轻微循环脉动。经验数字不放在 SCML 中，由人物状态区的文本组件动态叠加。

请保持 `.scml` 文件与 `CH0335_Experience_Halo_2tex` 图片目录的相对位置不变。
