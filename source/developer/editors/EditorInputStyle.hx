package developer.editors;

import general.backend.language.Language;
import general.backend.Paths;

/**
 * 各编辑器输入框统一「灰底白字」外观。
 *
 * 结论（经 WeekEditor 验证 + 诊断）：
 *  引擎 tile 渲染下原生控件文本不可靠的根源是 set_color 的白色早退 + TextField
 *  反射不可用。可靠做法 = 【构建期】直接改 flixel 持有的 _defaultFormat
 *  （haxe 对象，反射可写）把文本颜色设为白，让后续每次文本渲染都用白色格式；
 *  运行时弹层只做同样的直改 + _regen 标记。
 *
 * 背景/边框/caret 走官方 setter（calcFrame 会重建对应 sprite）。
 */
class EditorInputStyle
{
	public static final BG:Int = 0xFF12141A;
	public static final BORDER:Int = 0x26FFFFFF;

	/** 当前语言对应的字体文件名（读 main 语言组 fontName，缺失时按语言兜底） */
	public static function langFontFileName():String
	{
		var n:String = 'chillax';
		try { n = Language.get('fontName', 'main'); } catch (e:Dynamic) {}
		if (n == null || n == '' || n.indexOf('fontName') != -1 || n.indexOf('404') != -1)
			n = (ClientPrefs.data.language == 'Chinese') ? 'Lang-ZH' : 'chillax';
		return n + '.ttf';
	}

	/**
	 * 把输入控件染成灰底白字（构建期与弹层期均可调用，幂等）：
	 *  - 字体 = 对应语言的字体（main 组 fontName，如中文 Lang-ZH）
	 *  - 直接写 _defaultFormat.color = 白（绕过 FlxText.set_color 的白色早退）
	 *  - 背景灰 / 边框浅灰 / 光标白 / 字号 12
	 */
	public static function apply(w:Dynamic, ?fieldW:Float):Void
	{
		if (w == null) return;

		// ★ 字体：对应语言的字体（与菜单文本同一来源）
		try { w.font = Paths.font(langFontFileName()); } catch (e:Dynamic) {}

		// ★ 文本颜色：直接改 flixel 持有的 TextFormat（haxe 对象，Dynamic 可靠）
		try
		{
			var df:Dynamic = Reflect.field(w, '_defaultFormat');
			if (df != null)
				df.color = 0xFFFFFF;
		}
		catch (e:Dynamic) {}
		// 同步 color 字段（FlxSprite tint 用；不依赖其 setter 是否早退）
		try { w.color = 0xFFFFFFFF; } catch (e:Dynamic) {}

		try { w.backgroundColor = BG; } catch (e:Dynamic) {}
		try { w.fieldBorderColor = BORDER; } catch (e:Dynamic) {}
		try { w.caretColor = 0xFFFFFFFF; } catch (e:Dynamic) {}
		try { w.size = 12; } catch (e:Dynamic) {}
		if (fieldW != null)
		{
			try { w.fieldWidth = fieldW; } catch (e:Dynamic) {}
		}
		// 标记文本重渲（由绘制/后续 set_text 触发 calcFrame）
		try { Reflect.setField(w, '_regen', true); } catch (e:Dynamic) {}
	}

	/**
	 * 类型化设置 FlxInputText 的 hasFocus（必须走 setter）。
	 *
	 * set_hasFocus 内 `#if mobile` 会执行 window.textInputEnabled = true/false
	 * （SDL 弹/收安卓软键盘）。若用 Dynamic 赋值 `w.hasFocus = true` 会绕过
	 * setter 直接写字段 → 桌面一切正常（字符走 stage KEY_DOWN），安卓却永远
	 * 弹不出软键盘。
	 */
	public static function setInputFocus(w:Dynamic, focus:Bool):Void
	{
		if (w == null)
			return;
		if (Std.isOfType(w, flixel.addons.ui.FlxInputText))
		{
			var fi:flixel.addons.ui.FlxInputText = cast w;
			@:privateAccess fi.hasFocus = focus;
			return;
		}
		// 兜底：非 FlxInputText 的控件直接写字段
		try
		{
			Reflect.setProperty(w, 'hasFocus', focus);
		}
		catch (e:Dynamic) {}
	}
}
