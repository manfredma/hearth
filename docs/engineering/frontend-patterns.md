# 前端组件模式

Hearth 前端是 React + Vite 单页应用。组件必须通过 props 或明确的事件回调通信，样式和行为必须自隔离，不能依赖另一个页面路由是否加载了某个 CSS 文件。

## 组件约束

- 公共组件使用带前缀的 class 命名空间，例如 `hearth-*`。
- 组件样式放在承载组件且所有使用页面都会加载的样式文件中。
- 不用全局 `*`、裸标签选择器或页面主题资产覆盖其他组件。
- 弹窗必须支持键盘 Esc、焦点回收、移动端触控尺寸和明显的取消动作。
- 私人数据只从后端 API 获取并保存在 React 内存状态；禁止写入 localStorage、sessionStorage 或 URL。

## 响应式

桌面端采用侧边栏 + 主内容区；移动端折叠为顶部栏 + 抽屉导航。交互目标尺寸、对比度和文字层级以 [`frontend-design-language.md`](../architecture/frontend-design-language.md) 为准。
