package developer.editors;

import general.objects.WindowBarMode;
import general.objects.WindowControlBar;

/**
 * 编辑器顶栏使用的常驻窗口控制组（ChartEditor / CharacterEditor / StageEditor）。
 *
 * 系统标题栏在这些编辑器里被隐藏（沉浸式），由它在顶栏右上角接管窗口控制：
 *   [图标 NovaFlare Engine] │ - □ ×
 *
 * 实际实现与交互逻辑在 `WindowControlBar`（CONSTANT 模式）：
 * 最小化 / 最大化还原 / 关闭、悬停高亮、按住拖动窗口、双击最大化。
 */
class EditorChromeUI extends WindowControlBar
{
	public function new()
	{
		super(WindowBarMode.CONSTANT);
	}
}
