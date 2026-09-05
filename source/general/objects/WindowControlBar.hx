package general.objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxSpriteGroup;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.graphics.Image;
import openfl.display.BitmapData;
import openfl.utils.Assets;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

import general.backend.Paths;
import general.backend.Mods;
import general.backend.device.Native;

/**
 * 引擎自绘的“窗口控制条”（替代系统标题栏）。
 *
 * 两种模式：
 *  - CONSTANT（编辑器等）：常驻显示在界面顶栏右侧 —— [图标 NovaFlare Engine] │ - □ ×
 *  - AUTO_HIDE（所有普通界面）：平时完全隐藏，鼠标靠近窗口顶部时平滑滑入
 *    一条标题栏（含图标标题与 - □ × 与拖拽区），离开后自动滑出。
 *
 * 功能与系统标题栏一致：
 *  - 最小化 / 最大化还原 / 关闭（悬停高亮，Win11 风格，× 悬停变红）
 *  - 按住空白处拖动窗口、双击最大化 / 还原
 *
 * 组件由 `FlxG.signals.postUpdate` 全局驱动（不依赖具体状态的 update 链），
 * 只要游戏主循环在跑，按钮就始终响应。
 */
class WindowControlBar extends FlxSpriteGroup
{
	public static final BAR_HEIGHT:Int = 36;
	public static final BTN_W:Int = 46;

	// 悬停按钮的用途
	static final BTN_NONE:Int = 0;
	static final BTN_MIN:Int = 1;
	static final BTN_MAX:Int = 2;
	static final BTN_CLOSE:Int = 3;
	static final BTN_RESTORE:Int = 4; // 恢复到默认窗口大小/位置

	/** 全局每帧驱动 */
	static var tickers:Array<WindowControlBar> = [];
	static var tickHook:Bool = false;

	public var mode:WindowBarMode;

	// ---- 视觉元素 ----
	var iconSpr:FlxSprite;
	var titleTxt:FlxText;
	var sepLine:FlxSprite;
	var barBg:FlxSprite; // AUTO_HIDE 的整条背景
	var bottomLine:FlxSprite; // AUTO_HIDE 的底部分隔线
	var minHover:FlxSprite;
	var maxHover:FlxSprite;
	var closeHover:FlxSprite;
	var restoreHover:FlxSprite;
	var glyphGroup:FlxSpriteGroup;

	// ---- 布局（逻辑坐标） ----
	var minX:Float = 0;
	var maxX:Float = 0;
	var closeX:Float = 0;
	var restoreX:Float = 0;
	var lastLayoutW:Int = -1;

	// ---- 交互状态 ----
	var hoverBtn:Int = BTN_NONE;
	var isMaximized:Bool = false;
	var isFullscreen:Bool = false;
	var maxStateTimer:Float = 0;
	var lastClickTime:Float = -1;
	var lastClickX:Float = -99999;
	var lastClickY:Float = -99999;
	// 单击（标题区）与拖窗的区分
	var dragCandidate:Bool = false;
	var dragDownX:Float = 0;
	var dragDownY:Float = 0;
	var clickPending:Bool = false;
	var clickPendingTimer:Float = 0;
	var clickPendingX:Float = 0;
	var clickPendingY:Float = 0;

	/** CONSTANT 模式：单击标题/图标区（未拖动）时触发（如弹出 Mod 信息） */
	public var onTitleClick:Void->Void = null;

	/** 标题块（图标 + 标题文本）的左缘 X（逻辑坐标，供下拉面板对齐） */
	public function titleAnchorX():Float
	{
		return (iconSpr != null) ? iconSpr.x : 0;
	}

	/** 标题块宽度（图标 + 标题文本 + 间距） */
	public function titleBlockWidth():Float
	{
		if (titleTxt == null)
			return 0;
		var right:Float = titleTxt.x + titleTxt.width;
		return (right - titleAnchorX()) + 4;
	}

	// ---- AUTO_HIDE 动画状态 ----
	var slideY:Float = 0; // 0=完全展开, -BAR_HEIGHT=完全隐藏
	var showTimer:Float = 0;
	var hideTimer:Float = 0;
	var revealed:Bool = false; // 是否处于“唤出”状态

	// ---- 关闭淡出动效状态 ----
	var fadeOutState:Int = 0; // 0=无 1=淡出中 2=已透明，等待 1s 后关闭
	var fadeOutTimer:Float = 0;


	// ================= 构造 =================

	public function new(?mode:WindowBarMode = null)
	{
		if (mode == null)
			mode = WindowBarMode.CONSTANT;
		super();
		this.mode = mode;
		scrollFactor.set();
		#if (cpp && windows)
		if (!tickHook)
		{
			tickHook = true;
			FlxG.signals.postUpdate.add(tickAll);
		}
		tickers.push(this);

		buildUI();
		relayout();

		if (mode == WindowBarMode.AUTO_HIDE)
		{
			slideY = -BAR_HEIGHT;
			visible = false;
		}
		#end
	}

	static function tickAll():Void
	{
		var dt:Float = FlxG.elapsed;
		var i:Int = tickers.length - 1;
		while (i >= 0)
		{
			var bar:WindowControlBar = tickers[i];
			if (bar != null)
				bar.updateTick(dt);
			i--;
		}
	}

	/**
	 * 窗口模式（普通/最大化/全屏）切换后由 WindowChromeManager 调用：
	 * 强制重排并重建按钮图形、清空 hover 状态 —— 切换瞬间的 resize 事件
	 * 风暴可能让条内部的布局/高亮状态残留（表现为按钮消失/错位/全亮）。
	 */
	public static function refreshAllBars():Void
	{
		for (bar in tickers)
		{
			if (bar != null && bar.exists)
			{
				bar.relayout();
				bar.hoverBtn = BTN_NONE;
				if (bar.restoreHover != null) bar.restoreHover.visible = false;
				if (bar.minHover != null) bar.minHover.visible = false;
				if (bar.maxHover != null) bar.maxHover.visible = false;
				if (bar.closeHover != null) bar.closeHover.visible = false;
			}
		}
	}

	// ================= 构建 =================

	function buildUI():Void
	{
		if (mode == WindowBarMode.AUTO_HIDE)
		{
			// 整条深色背景（模拟标题栏）+ 底部 1px 亮线
			barBg = new FlxSprite().makeGraphic(1, BAR_HEIGHT, 0xFF202020);
			barBg.x = 0;
			barBg.y = 0;
			add(barBg);
			bottomLine = new FlxSprite().makeGraphic(1, 1, 0xFF4A4A4A);
			bottomLine.x = 0;
			bottomLine.y = BAR_HEIGHT - 1;
			add(bottomLine);
		}

		// 引擎图标（优先当前 mod 的 pack 图标，其次 icon.ico，最后内置渐变兜底）
		iconSpr = new FlxSprite();
		loadBarIcon();
		iconSpr.y = (BAR_HEIGHT - iconSpr.height) / 2;
		add(iconSpr);

		titleTxt = new FlxText(0, 0, 0, "NovaFlare Engine");
		titleTxt.setFormat(Assets.getFont("assets/fonts/montserrat.ttf").fontName, 13, 0xFFBDBDBD);
		titleTxt.antialiasing = true;
		titleTxt.y = (BAR_HEIGHT - titleTxt.height) / 2;
		add(titleTxt);

		sepLine = new FlxSprite().makeGraphic(1, BAR_HEIGHT - 12, 0xFF4A4A4A);
		sepLine.y = 6;
		add(sepLine);

		// hover 高亮层
		restoreHover = new FlxSprite().makeGraphic(BTN_W, BAR_HEIGHT, 0x26FFFFFF);
		minHover = new FlxSprite().makeGraphic(BTN_W, BAR_HEIGHT, 0x26FFFFFF);
		maxHover = new FlxSprite().makeGraphic(BTN_W, BAR_HEIGHT, 0x26FFFFFF);
		closeHover = new FlxSprite().makeGraphic(BTN_W, BAR_HEIGHT, 0xFFC42B1C);
		restoreHover.visible = false;
		minHover.visible = false;
		maxHover.visible = false;
		closeHover.visible = false;
		add(restoreHover);
		add(minHover);
		add(maxHover);
		add(closeHover);

		glyphGroup = new FlxSpriteGroup();
		add(glyphGroup);
	}

	static inline final ICON_SIZE:Int = 18; // 条内图标显示尺寸

	/**
	 * 加载条上的引擎 / 模组图标：
	 * 1. 当前 mod 的 pack.png / pack-pixel.png（150px 帧；图片宽 >150 时按
	 *    150x150 从左到右、从上到下切帧循环播放 —— 与 Mod 选择界面一致）
	 * 2. 引擎 icon.ico（提取其中最大的 PNG 帧）
	 * 3. 官方小组图标兜底
	 * 4. 蓝紫渐变兜底
	 */
	function loadBarIcon():Void
	{
		// 1) 当前 mod 的 pack 图标
		var folder:String = Mods.currentModDirectory;
		var graphic:FlxGraphic = null;
		var pixelArt:Bool = false;
		if (folder != null && folder.length > 0)
		{
			graphic = Paths.cacheBitmap(Paths.mods('$folder/pack.png'));
			if (graphic == null)
			{
				graphic = Paths.cacheBitmap(Paths.mods('$folder/pack-pixel.png'));
				pixelArt = graphic != null;
			}
		}

		if (graphic != null)
		{
			iconSpr.loadGraphic(graphic, true, 150, 150);
			iconSpr.antialiasing = !pixelArt;
			var frames:Int = Math.floor(graphic.width / 150) * Math.floor(graphic.height / 150);
			if (frames < 1) frames = 1;
			if (frames > 1)
			{
				iconSpr.animation.add('icon', [for (i in 0...frames) i], 10);
				iconSpr.animation.play('icon');
			}
			iconSpr.setGraphicSize(ICON_SIZE, ICON_SIZE);
			iconSpr.updateHitbox();
			return;
		}

		// 2) 引擎 icon.ico（游戏运行目录）
		graphic = loadIcoGraphic();
		if (graphic != null)
		{
			iconSpr.loadGraphic(graphic);
			iconSpr.antialiasing = true;
			iconSpr.setGraphicSize(ICON_SIZE, ICON_SIZE);
			iconSpr.updateHitbox();
			return;
		}

		// 3) 官方小组图标
		graphic = Paths.cacheBitmap(Paths.getSharedPath('images/menuExtend/CreditsState/groupIcon/NovaFlare Engine.png'));
		if (graphic != null)
		{
			iconSpr.loadGraphic(graphic);
			iconSpr.antialiasing = true;
			iconSpr.setGraphicSize(ICON_SIZE, ICON_SIZE);
			iconSpr.updateHitbox();
			return;
		}

		// 4) 蓝紫渐变兜底
		iconSpr.makeGraphic(ICON_SIZE, ICON_SIZE, FlxColor.TRANSPARENT, true);
		var pix = iconSpr.pixels;
		for (y in 0...ICON_SIZE)
		{
			var t:Float = y / (ICON_SIZE - 1);
			var r:Int = Std.int(0x4F + (0x7C - 0x4F) * t);
			var g:Int = Std.int(0xC3 + (0x4D - 0xC3) * t);
			var b:Int = Std.int(0xF7 + (0xFF - 0xF7) * t);
			for (x in 0...ICON_SIZE)
				pix.setPixel32(x, y, (0xFF << 24) | (r << 16) | (g << 8) | b);
		}
		iconSpr.antialiasing = true;
	}

	/** 从运行目录 icon.ico 提取最大的 PNG 帧 */
	static function loadIcoGraphic():FlxGraphic
	{
		#if sys
		try
		{
			if (!FileSystem.exists('icon.ico'))
				return null;
			var bytes = File.getBytes('icon.ico');
			if (bytes.length < 6)
				return null;
			var count:Int = bytes.get(4) | (bytes.get(5) << 8);
			var bestSize:Int = 0;
			var bestOff:Int = -1;
			var bestLen:Int = 0;
			for (i in 0...count)
			{
				var p:Int = 6 + i * 16;
				if (p + 16 > bytes.length)
					break;
				var w:Int = bytes.get(p);
				if (w == 0) w = 256;
				var h:Int = bytes.get(p + 1);
				if (h == 0) h = 256;
				var len:Int = bytes.get(p + 8) | (bytes.get(p + 9) << 8) | (bytes.get(p + 10) << 16) | (bytes.get(p + 11) << 24);
				var off:Int = bytes.get(p + 12) | (bytes.get(p + 13) << 8) | (bytes.get(p + 14) << 16) | (bytes.get(p + 15) << 24);
				if (len > 0 && off + len <= bytes.length && w * h >= bestSize)
				{
					bestSize = w * h;
					bestOff = off;
					bestLen = len;
				}
			}
			if (bestOff < 0)
				return null;
			var data = bytes.sub(bestOff, bestLen);
			// 只支持 PNG 编码的 ICO 帧（现代 .ico 常见）
			if (data.length < 8 || data.get(0) != 0x89 || data.get(1) != 0x50 || data.get(2) != 0x4E || data.get(3) != 0x47)
				return null;
			var img:Image = Image.fromBytes(data);
			var bd:BitmapData = BitmapData.fromImage(img);
			return FlxGraphic.fromBitmapData(bd);
		}
		catch (e:Dynamic) {}
		#end
		return null;
	}

	// ================= 布局 =================

	function relayout(?layoutW:Int = 0):Void
	{
		var w:Float = (layoutW > 0) ? layoutW : FlxG.width;

		closeX = w - BTN_W;
		maxX = closeX - BTN_W;
		minX = maxX - BTN_W;

		restoreX = minX - BTN_W;

		if (mode == WindowBarMode.AUTO_HIDE)
		{
			// 整条背景 + 底部线拉满，标题靠左
			barBg.makeGraphic(Std.int(w), BAR_HEIGHT, 0xFF202020);
			barBg.x = 0;
			bottomLine.makeGraphic(Std.int(w), 1, 0xFF4A4A4A);
			bottomLine.x = 0;
			titleTxt.x = 46;
			iconSpr.x = 16;
			sepLine.visible = false;
			sepLine.x = 0;
		}
		else
		{
			// CONSTANT：标题右对齐到“恢复默认”按钮左侧
			var titleRight:Float = restoreX - 16;
			titleTxt.x = titleRight - titleTxt.width;
			iconSpr.x = titleTxt.x - 22;
			sepLine.x = iconSpr.x - 12;
			sepLine.visible = true;
		}

		restoreHover.x = restoreX;
		minHover.x = minX;
		maxHover.x = maxX;
		closeHover.x = closeX;

		rebuildGlyphs();
		lastLayoutW = Std.int(w);
	}

	function hLine(w:Int, color:FlxColor, parent:FlxSpriteGroup):FlxSprite
	{
		var s = new FlxSprite().makeGraphic(w, 1, color);
		parent.add(s);
		return s;
	}

	function vLine(h:Int, color:FlxColor, parent:FlxSpriteGroup):FlxSprite
	{
		var s = new FlxSprite().makeGraphic(1, h, color);
		parent.add(s);
		return s;
	}

	function rebuildGlyphs():Void
	{
		while (glyphGroup.members.length > 0)
			glyphGroup.remove(glyphGroup.members[0], true);

		// ★ 条隐藏/滑入过程中重建时，glyph 的 y 必须加上当前滑动偏移：
		//   FlxSpriteGroup 的成员是"场景坐标"，条 y=slideY 只是批量平移成员；
		//   这里新建的成员不会自动继承平移，若在 slideY≠0 时重建（如全屏切换
		//   后 0.25s 的 □ 状态重建恰逢条滑入），按钮组会与条背景错位一个条高。
		var yOff:Float = (mode == WindowBarMode.AUTO_HIDE) ? slideY : 0;

		// —— 恢复到默认窗口大小：外框 + 中心小方块
		{
			var ox:Float = restoreX + (BTN_W - 12) / 2;
			var oy:Float = (BAR_HEIGHT - 12) / 2 + yOff;
			var t = hLine(12, 0xFFD8D8D8, glyphGroup); t.x = ox; t.y = oy;
			var b = hLine(12, 0xFFD8D8D8, glyphGroup); b.x = ox; b.y = oy + 11;
			var l = vLine(12, 0xFFD8D8D8, glyphGroup); l.x = ox; l.y = oy;
			var r = vLine(12, 0xFFD8D8D8, glyphGroup); r.x = ox + 11; r.y = oy;
			var dot = new FlxSprite().makeGraphic(4, 4, 0xFFD8D8D8);
			dot.x = ox + 4;
			dot.y = oy + 4;
			glyphGroup.add(dot);
		}

		// —— 最小化：横线
		var minLine = hLine(10, 0xFFD8D8D8, glyphGroup);
		minLine.x = minX + (BTN_W - 10) / 2;
		minLine.y = BAR_HEIGHT / 2 + yOff;

		// —— 最大化 / 还原（AUTO_HIDE 的 □ 表示全屏切换，状态看 isFullscreen）
		if (mode == WindowBarMode.AUTO_HIDE ? isFullscreen : isMaximized)
		{
			// 还原：外框 + 内框错位
			var ox:Float = maxX + 13;
			var oy:Float = 7 + yOff;
			var t1 = hLine(10, 0xFFD8D8D8, glyphGroup); t1.x = ox; t1.y = oy;
			var b1 = hLine(10, 0xFFD8D8D8, glyphGroup); b1.x = ox; b1.y = oy + 9;
			var l1 = vLine(9, 0xFFD8D8D8, glyphGroup); l1.x = ox; l1.y = oy;
			var r1 = vLine(9, 0xFFD8D8D8, glyphGroup); r1.x = ox + 9; r1.y = oy;
			var t2 = hLine(7, 0xFFD8D8D8, glyphGroup); t2.x = ox + 2; t2.y = oy + 2;
			var b2 = hLine(7, 0xFFD8D8D8, glyphGroup); b2.x = ox + 2; b2.y = oy + 11;
			var l2 = vLine(6, 0xFFD8D8D8, glyphGroup); l2.x = ox + 2; l2.y = oy + 2;
			var r2 = vLine(6, 0xFFD8D8D8, glyphGroup); r2.x = ox + 9; r2.y = oy + 2;
			// 用深色条盖住外框被内框穿过的部分，模拟层级
			var cover = new FlxSprite().makeGraphic(3, 2, mode == WindowBarMode.AUTO_HIDE ? 0xFF202020 : 0xFF3A3A3A);
			cover.x = ox + 2;
			cover.y = oy + 8;
			glyphGroup.add(cover);
		}
		else
		{
			var ox:Float = maxX + (BTN_W - 12) / 2;
			var oy:Float = (BAR_HEIGHT - 12) / 2 + yOff;
			var t = hLine(12, 0xFFD8D8D8, glyphGroup); t.x = ox; t.y = oy;
			var b = hLine(12, 0xFFD8D8D8, glyphGroup); b.x = ox; b.y = oy + 11;
			var l = vLine(12, 0xFFD8D8D8, glyphGroup); l.x = ox; l.y = oy;
			var r = vLine(12, 0xFFD8D8D8, glyphGroup); r.x = ox + 11; r.y = oy;
		}

		// —— 关闭：×（两条 45° 线，绕自身中心旋转）
		var c1 = hLine(10, 0xFFD8D8D8, glyphGroup);
		c1.x = closeX + (BTN_W - 10) / 2;
		c1.y = BAR_HEIGHT / 2 + yOff;
		c1.origin.set(5, 0.5);
		c1.angle = 45;
		var c2 = hLine(10, 0xFFD8D8D8, glyphGroup);
		c2.x = closeX + (BTN_W - 10) / 2;
		c2.y = BAR_HEIGHT / 2 + yOff;
		c2.origin.set(5, 0.5);
		c2.angle = -45;
	}

	// ================= 每帧驱动 =================

	function updateTick(elapsed:Float):Void
	{
		#if (cpp && windows)
		// 保持渲染在最顶层（TitleState 的视频、状态后期 add 的 UI 不会盖住窗口条）
		keepOnTop();

		// 布局基准：FlxG.width（沉浸视口在窗口尺寸变化时由 onMeasure 更新，
		// 按钮组自动贴紧右缘）。不做额外的物理换算，避免抖动。
		if (FlxG.width != lastLayoutW)
			relayout();

		// 窗口按钮状态图标（节流）：□ 反映"非窗口化"（全屏/最大化，显示还原图标）。
		// 注意：沉浸窗口是无边框(WS_POPUP/borderless)，系统 ShowWindow(SW_MAXIMIZE)
		// 会把窗口铺满整个屏幕(=全屏 mode 2)，不存在"工作区最大化(mode 1)"，
		// 所以 CONSTANT 的 □ 语义与 AUTO_HIDE 相同：全屏切换，状态看 windowMode()==2。
		maxStateTimer -= elapsed;
		if (maxStateTimer <= 0)
		{
			maxStateTimer = 0.25;
			var nowFs:Bool = Native.windowMode() == 2;
			if (mode == WindowBarMode.AUTO_HIDE)
			{
				if (nowFs != isFullscreen)
				{
					isFullscreen = nowFs;
					rebuildGlyphs();
				}
			}
			else
			{
				if (nowFs != isMaximized)
				{
					isMaximized = nowFs;
					rebuildGlyphs();
				}
			}
		}

		if (mode == WindowBarMode.AUTO_HIDE)
		{
			updateAutoHide(elapsed);
			y = slideY;
		}
		else
		{
			y = 0;
		}

		// （窗口缩放动画已废弃：最大化/还原直接走系统 ShowWindow，
		//   视口同步由 WindowChromeManager 的轮询对账负责）

		// 关闭淡出：整个窗口透明度 255 → 0（0.45s）→ 保持全透明 0.4s → 真正退出。
		// 用 WS_EX_LAYERED + SetLayeredWindowAttributes 做整窗合成透明度，
		// 淡出的是“程序窗口”本身而不是画面里的元素。
		if (fadeOutState > 0)
		{
			if (fadeOutState == 1)
			{
				// 全屏下 layered 透明度不可靠：先还原窗口再开始淡出
				if (Native.windowMode() != 0)
					Native.windowApplyMode(0);
				else
				{
					fadeOutTimer += elapsed;
					var t:Float = Math.min(1, fadeOutTimer / 0.45);
					Native.windowSetAlpha(Std.int(255 * (1 - t)));
					if (fadeOutTimer >= 0.45)
					{
						Native.windowSetAlpha(0);
						fadeOutState = 2;
						fadeOutTimer = 0;
					}
				}
			}
			else if (fadeOutState == 2)
			{
				fadeOutTimer += elapsed;
				if (fadeOutTimer >= 0.4)
				{
					fadeOutState = 0;
					Native.windowClose();
				}
			}
			return;
		}

		updateInteraction(elapsed);

		// ★ SpriteGroup 的 visible 切换（AUTO_HIDE 滑入/滑出）会把所有子对象
		//   visible 置 true —— hover 高亮层会被一起点亮。这里每帧无条件按
		//   hoverBtn 校正它们的可见性（不能只靠 clearHover：hoverBtn 为
		//   NONE 时它不会执行）。
		restoreHover.visible = (hoverBtn == BTN_RESTORE);
		minHover.visible = (hoverBtn == BTN_MIN);
		maxHover.visible = (hoverBtn == BTN_MAX);
		closeHover.visible = (hoverBtn == BTN_CLOSE);
		if (sepLine != null)
			sepLine.visible = (mode == WindowBarMode.CONSTANT);
		#end
	}

	/** 开始关闭淡出流程：整个窗口透明度逐渐变为 0，然后退出 */
	function startFadeOut():Void
	{
		if (fadeOutState > 0)
			return;
		fadeOutState = 1;
		fadeOutTimer = 0;
	}

	/** 把自己挪到父状态 members 的末尾（最顶层） */
	function keepOnTop():Void
	{
		var st:FlxState = FlxG.state;
		if (st == null || st.members == null || st.members.length == 0)
			return;
		if (st.members[st.members.length - 1] == this)
			return;
		if (st.members.remove(this))
			st.members.push(this);
	}

	/** 光标在窗口内的物理坐标（原生轮询，不依赖鼠标事件）；不在窗口内返回 null */
	function cursorPhys():FlxPoint
	{
		var cx:Int = Native.cursorClientX();
		var cy:Int = Native.cursorClientY();
		if (cx < 0 || cy < 0)
			return null;
		return FlxPoint.get(cx, cy);
	}

	/** 逻辑 X → 渲染后的物理 X（与相机渲染同公式：× scale + 游戏偏移） */
	function physX(logicalX:Float):Float
	{
		var sx:Float = FlxG.scaleMode.scale.x;
		if (sx <= 0) sx = 1;
		return logicalX * sx + FlxG.game.x;
	}

	function physY(logicalY:Float):Float
	{
		var sy:Float = FlxG.scaleMode.scale.y;
		if (sy <= 0) sy = 1;
		return logicalY * sy + FlxG.game.y;
	}

	/** AUTO_HIDE：靠近顶部唤出 / 离开隐藏 + 滑入滑出动画 */
	function updateAutoHide(elapsed:Float):Void
	{
		// 原生轮询只用于"光标是否在窗口上 / 是否贴近顶部条带"（物理判定）
		var pos:FlxPoint = cursorPhys();
		var over:Bool = pos != null;
		var myPhys:Float = (pos != null) ? pos.y : 999999;
		if (pos != null)
			pos.put();

		// 唤出条带 = 条高 + 12 逻辑像素的渲染物理高度
		var stripPhys:Float = physY(BAR_HEIGHT + 12) - FlxG.game.y;

		// 拖动中保持展开
		if (Native.windowDragging())
		{
			showTimer = 0;
			hideTimer = 0;
		}
		else if (over && myPhys < stripPhys)
		{
			// 光标靠近顶部 → 唤出
			showTimer += elapsed;
			hideTimer = 0;
			if (showTimer >= 0.12)
				revealed = true;
		}
		else
		{
			// 光标离开条带 → 收起
			showTimer = 0;
			if (revealed)
			{
				hideTimer += elapsed;
				if (hideTimer >= 0.5)
					revealed = false;
			}
			else
				hideTimer = 0;
		}

		// 滑入 / 滑出动画
		var targetY:Float = revealed ? 0 : -BAR_HEIGHT;
		slideY += (targetY - slideY) * Math.min(1, elapsed * 18);

		if (slideY > -BAR_HEIGHT * 0.98)
			visible = true;
		else if (slideY <= -BAR_HEIGHT + 0.05)
			visible = false;
	}

	/** 按钮 hover / 点击 / 拖动。
	 *  鼠标位置用 `getWorldPosition(本条相机)` 换算 —— flixel 官方变换
	 *  （含相机 zoom / scroll / 视口偏移 / scaleMode），与渲染严格同源。 */
	function updateInteraction(elapsed:Float):Void
	{
		// 窗口缩放动画进行中不响应点击/拖动
		if (Native.windowAnimRunning())
			return;

		// 光标不在窗口上 → 清除高亮，不处理
		var phys:FlxPoint = cursorPhys();
		if (phys == null)
		{
			clearHover();
			return;
		}
		phys.put();

		// 条是否大部分可见（AUTO_HIDE 滑出中途不响应）
		if (mode == WindowBarMode.AUTO_HIDE && slideY < -BAR_HEIGHT * 0.5)
		{
			clearHover();
			return;
		}

		if (Native.windowDragging())
		{
			Native.windowDragUpdate();
			if (!FlxG.mouse.pressed)
				Native.windowDragEnd();
			clearHover();
			return;
		}

		// 鼠标在条所在相机里的世界坐标
		var cam:flixel.FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
		var mpos:FlxPoint = FlxG.mouse.getWorldPosition(cam);
		var mx:Float = mpos.x;
		var my:Float = mpos.y - ((mode == WindowBarMode.AUTO_HIDE) ? slideY : 0);
		mpos.put();

		// hover 高亮（光标必须在条的可视范围内）
		var overBtn:Int = BTN_NONE;
		if (my >= 0 && my < BAR_HEIGHT)
		{
			if (mx >= closeX && mx < closeX + BTN_W)
				overBtn = BTN_CLOSE;
			else if (mx >= maxX && mx < maxX + BTN_W)
				overBtn = BTN_MAX;
			else if (mx >= minX && mx < minX + BTN_W)
				overBtn = BTN_MIN;
			else if (mx >= restoreX && mx < restoreX + BTN_W)
				overBtn = BTN_RESTORE;
		}
		if (overBtn != hoverBtn)
		{
			hoverBtn = overBtn;
			restoreHover.visible = (hoverBtn == BTN_RESTORE);
			minHover.visible = (hoverBtn == BTN_MIN);
			maxHover.visible = (hoverBtn == BTN_MAX);
			closeHover.visible = (hoverBtn == BTN_CLOSE);
		}

		// —— 延迟单击触发（等待双击窗口结束）——
		if (clickPending)
		{
			clickPendingTimer += elapsed;
			if (clickPendingTimer >= 0.3)
			{
				clickPending = false;
				if (mode == WindowBarMode.CONSTANT && onTitleClick != null)
					onTitleClick();
			}
		}

		// —— 拖动候选：按住移动超过阈值才真正拖窗；原地松开视为单击 ——
		if (dragCandidate)
		{
			if (FlxG.mouse.justReleased)
			{
				dragCandidate = false;
				clickPending = true;
				clickPendingTimer = 0;
			}
			else if (!FlxG.mouse.pressed)
				dragCandidate = false;
			else if (Math.abs(mx - dragDownX) > 5 || Math.abs(my - dragDownY) > 5)
			{
				dragCandidate = false;
				Native.windowDragBegin();
			}
		}

		if (!FlxG.mouse.justPressed)
			return;

		// 新按下：取消待触发的单击（可能是双击）
		clickPending = false;

		if (overBtn == BTN_CLOSE)
		{
			// 关闭：画面淡出，等 1 秒后再真正退出
			startFadeOut();
		}
		else if (overBtn == BTN_MAX)
		{
			// □ = 全屏切换（无边框沉浸窗口的最大化即全屏，两种模式语义一致）
			Native.windowApplyMode(Native.windowMode() == 2 ? 0 : 2);
		}
		else if (overBtn == BTN_MIN)
		{
			// 最小化：直接系统最小化（不带自定义动画）
			Native.windowMinimize();
		}
		else if (overBtn == BTN_RESTORE)
		{
			// 恢复到默认窗口大小与位置（全屏/最大化下先还原再恢复默认）
			if (Native.windowMode() != 0)
				Native.windowApplyMode(0);
			Native.windowRestoreDefault();
		}
		else if (my >= 0 && my < BAR_HEIGHT && isDragZone(mx))
		{
			// 双击最大化 / 还原（无边框窗口的最大化即全屏，双击 = 全屏切换）
			var now:Float = FlxG.game.ticks / 1000;
			if (now - lastClickTime < 0.3 && Math.abs(mx - lastClickX) < 8 && Math.abs(my - lastClickY) < 8)
			{
				lastClickTime = -1;
				dragCandidate = false;
				clickPending = false;
				Native.windowApplyMode(Native.windowMode() == 2 ? 0 : 2);
			}
			else
			{
				lastClickTime = now;
				lastClickX = mx;
				lastClickY = my;
				// 先进入“候选拖动”
				dragCandidate = true;
				dragDownX = mx;
				dragDownY = my;
			}
		}
	}

	function isDragZone(mx:Float):Bool
	{
		if (mode == WindowBarMode.AUTO_HIDE)
			return mx < restoreX; // AUTO_HIDE：除按钮区外整条可拖
		return mx >= sepLine.x + 1 && mx < restoreX; // CONSTANT：分隔线右侧、按钮左侧
	}

	function clearHover():Void
	{
		if (hoverBtn != BTN_NONE)
		{
			hoverBtn = BTN_NONE;
			restoreHover.visible = false;
			minHover.visible = false;
			maxHover.visible = false;
			closeHover.visible = false;
		}
	}

	// ================= 生命周期 =================

	override function destroy()
	{
		#if (cpp && windows)
		tickers.remove(this);
		if (Native.windowDragging())
			Native.windowDragEnd();
		#end
		super.destroy();
	}
}
