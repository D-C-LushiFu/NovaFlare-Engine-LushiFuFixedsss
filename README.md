# Novaflare-ENgine1.2.0LanguageFix
我操了老铁们1.2.0被🕊了一点小功能所以我选择小改一下希望beihu235不会咬我（


====================Chinese


你所能见到的所有元素（啊除了指定使用字符集xml的）都支持了utf-8的显示
在mod制作相关的玩意中（如编谱器等）已成功汉化（当然你也可以去setting里面调整language选项调成别的但是谁知道呢）
修复了charting Mode中调整Mania值后编谱器不更改相对应的图标编辑问题
在freeplay中添加了音频可视化
更改了一下主菜单的显示
你现在可以把在开头显示的文本全部更改为utf-8的所有字符（前提是你的vcr.ttf是支持显示的不然的话显示不出来不要怪我）
目前的话就这些


====================English


All the elements you can see (ah, except those that specifically use the XML character set) now support UTF-8 display. 
In mod-making-related tools (such as chart editors, etc.), it has been successfully localized into Chinese (of course, you can also go to the settings and change the language option to something else, but who knows). 
Fixed the issue in charting mode where changing the Mania value did not update the corresponding icon in the chart editor. 
Added audio visualization in freeplay. 
Made some changes to the main menu display. 
You can now change all the text displayed at the beginning to any UTF-8 characters (as long as your vcr.ttf supports displaying them; otherwise, it won’t show up, so don’t blame me). 
That's all for now.


---

# NovaFlare Engine 1.2.1ButLushiFuFixxxxx更新总览

## 一、总体改动主题（六大工程）

### 1. 编辑器 UI 全面换代：Adobe 风格顶栏菜单 + 状态栏 + 自绘控件

谱面/角色/菜单角色/舞台编辑器统一从旧 `FlxUITabMenu` 标签页 + 底部按钮，翻新为"顶栏下拉菜单（MenuBar）+ 底部状态栏（StatusBar）+ NovaFlare 深色渐变主题"。核心架构是**原生 FlxUI 控件只作隐藏数据源，外观与交互全部自绘**（stepper/dropdown/input/slider、勾选行、动作行、走马灯、hover 描述条），并规避了大量 FlxUI 运行坑（隐藏组必须 `active=false`、`clear()` 僵尸成员、焦点抢断等）。

- 新增：`ChartEditorMenuBar/StatusBar`、`CharacterEditorMenuBar/StatusBar`、`StageEditorMenuBar/StatusBar`、`EditorChromeUI`、`EditorInputStyle`、`WeekSongRect`、`StageEditorConfirmSubstate`
- 功能增强：Stage 编辑器新增撤销栈 Ctrl+Z（50 层快照）、剪贴板 Ctrl+C/X/V、Delete 确认删除、多 PNG/任意路径素材导入（实现基准里遗留的 TO DO）、教程浮层；角色编辑器 Ctrl+S 快存、F1 帮助；谱面编辑器补齐小节 swap/duet/mirror/copyBeat、undo 从占位注释变为可用（haxe.Serializer 快照）

### 2. 全面多语言化 + 中文字体渲染

约 30 个文件把硬编码 `vcr.ttf` 换成 `Language.get('fontName','main')`（中文界面走 Lang-ZH.ttf，英文默认 chillax），菜单/提示/按钮文案改为语言 key。核心是 **`Alphabet.hx` 重构**：逐字精灵动画（AlphaCharacter/alphabet.png 字符表）→ 按语言 TTF 的逐字符 FlxText，为中文渲染铺路。`Language`/`CustomLangGroup` 增加 openfl Assets 清单回退，解决安卓 APK 内无法列目录的问题。

### 3. Windows"沉浸式自绘窗口"体系（桌面）

`Native.hx` 新增约 970 行原生原语（运行时增删 WS_CAPTION/WS_THICKFRAME 标题栏、SetCapture 手动拖窗、窗口矩形动画、整窗淡出、分辨率确认 MessageBox 独立线程），`WindowChromeManager` 按界面隐藏系统标题栏并做视口同步对账，`WindowControlBar` 自绘标题栏（AUTO_HIDE 靠顶唤出 / CONSTANT 编辑器常驻）。注释记录了工程史：纯 SetWindowPos/自绘动画方案破坏 SDL→OpenGL 呈现被放弃，最终收敛为 SDL 正规全屏 + 系统 ShowWindow + 同步 `borderless`。

### 4. 移动端虚拟按键自定义体系（全新功能线）

- 新增 `EditorMobileKeys`（总管理：开关持久化、三级文件回退、主线程模板缓存）、`EditorMobileKeyOverlay`（运行时覆盖层：独立 HUD 相机、0.8s mtime 热重载、父键档位模型）、`EditorMobileKeyData`（9 个编辑器的按键注册表/语义表/JSON 解析）、`EditorMobileKeyDefaults`（APK 内置模板）
- 新增 `EditorKeyServer`：游戏内嵌本地 HTTP 服务（127.0.0.1:1146~1165 自动回落），子线程只 accept、绝不碰 FlxG；配合生成的整页 HTML 常量 `EditorKeyPage`，在浏览器里可视化摆位/录组合键/配置 Switch 父键并回写 `<Editor>NewFuckingButtonMobile.json`
- 接线：`MusicBeatState` 通知钩子、`MaintenanceGroup` 新增 `adjustMobileEditorKeys` 维护选项、`InitState` 新增 `-emk` 调试开关

### 5. 键位设置界面换代

新增 `KeyBindsSubState.hx`（669 行，基线不存在）：分类标签 + 真实键盘示意图 + 双槽位 + TAB 切换 + 每 K 档专属高亮色；OptionsState 的按键绑定入口由旧 `ControlsSubState` 切到它。旧的两个 ControlsSubState 同步重构数据表（分组标题行 + 双语条目），ESC 取消阈值统一 0.5s→2.0s。

### 6. 编辑器/调试工具体验

- Trace 控制台窗口与 LOG 按钮**位置/尺寸记忆**（`consoleX/Y/W/H`、`consoleButtonX/Y`）
- 新增 `ModInfoPopup`（mod 信息面板，空状态解锁"自欺欺人"成就）
- `TitleState` 跳过 intro 改为 0.35s 内双击鼠标防误触
- `EditorPlayState` 试玩加 4 拍 3,2,1,GO 彩色倒计时 + 音效

---

## 二、重点 Bug 修复清单（按模块）

| 模块 | 修复内容 |
|---|---|
| **ChartingState** | ① mania/键数载入不再平移数据（修非 4K 谱被二次平移错乱）；② 事件音符判定 `[2]==null` → `Std.is(note[1], Array)`，消除多处把普通音符 Int 当数组索引导致的 ACCESS_VIOLATION；③ Z/X 缩放 `zoomList[-1]` 越界、除零、0 行位图；④ changeSection 换边强制重画、`lastSecBeatsNext` 漏赋值 |
| **StageEditorState** | ① 退出编辑器不还原 `Paths.currentLevel/StageData.forceNextDirectory/Mods.currentModDirectory/临时SONG` 等全局静态（原残留 week 目录污染游戏图片解析）；② 隐藏旧 UI 后"幽灵点击"误重启编辑器；③ 复制无动画对象崩溃（null 守卫）；④ ESC 先关浮层防误退；⑤ draw 顺序反转防背景盖角色；⑥ 分步销毁/逐帧纹理预上传状态机防卡顿 |
| **WeekEditorState** | ① `addVirtualPad` 移到 `super.create()` 之后（修复 `cameras.reset` 销毁移动端按键相机后点击即崩）；② 隐藏面板必须 `active=false`（否则空 frame `calcFrame()` 崩溃）；③ `destroy()` 取消 tween + 回调判空（FlxPoint 池置 null 原生崩溃） |
| **MenuCharacterEditorState** | `onLoadComplete` 原来把 image/idle/confirm 三个输入框**全填成 `characterFile.image`**（复制粘贴错误），现分别填入正确字段 |
| **EditorPlayState** | Pe-1.0.4 非 4K 谱 ESC 试玩时 mustPress/gfNote 归属错乱（按 chartEngineVersion 分支解析，与 PlayState 对齐） |
| **Note** | `initializeGlobalRGBShader` 对 `noteData=-1`（事件音符）等非法索引**负越界写内存**，现统一返回共享默认 RGBPalette |
| **DataPreload** | `File.getContent()` 结果未赋值导致 hscript 预载静默失效；Lua/hscript 解析包 try/catch，坏 mod 不再崩加载页 |
| **Paths** | 图片缓存命中校验 bitmap 有效性，防返回已释放 graphic 导致渲染崩溃 |
| **PsychUIInputText / PsychUIRadioGroup / Option** | destroy 后 `_boundaries` 置 null 并三处补 NPE 防护；`set_labels` 后 checked 夹取防越界；`updateDisText` 补 null 守卫 |
| **ConsoleToggleButton** | LOG 按钮拖动与点击判定（5px 阈值），修复"拖完误展开" |
| **全屏策略** | 不再把 F11 全屏写进存档、默认窗口化启动、迁移清掉旧存档 `fullscreen=true` 残留 |

---


**一句话概括**：这次修改是围绕"编辑器体验现代化（自绘顶栏菜单/状态栏/深色主题）→ 中文本地化渲染 → Windows 沉浸式窗口 → 移动端按键可视化自定义"四条主线的大规模增强，同时修复了数十处崩溃级问题（越界写内存、数组负索引、全局静态污染、控件生命周期 NPE、非 4K 谱解析错乱等），属于功能迭代 + 稳定性修复并重的一次改版。


### NovaFlare Engine 1.2.1ButLushiFuFixxxxx
only me,yet,right

只有我，嗯对。

|Icon|Name|Involvement|
|----|----|-----------|
|![D.C.LushiFu](https://github.com/D-C-LushiFu.png)|[D.C.LushiFu](https://space.bilibili.com/3461571971910090)|翻新大部分常用的Editor界面UI并解决了一些如同薛定谔的猫一样的bug

# 然后下面是原NF的md。我不想受到无妄之灾(懂我意思)
---




---

<div align="center">
  <img src="https://raw.githubusercontent.com/NovaFlare-Engine-Concentration/NovaFlare-Engine.github.io/refs/heads/main/images/logo2.png" width="380" alt="NovaFlare Icon"></img>
  <br/>
  <h1 align="center">Friday Night Funkin' - NovaFlare Engine</h1>
  <p align="center">Engine based on Psych originally used on VS Camellia fanmade and focused on optimisation and perfomance to give players best possible experience. It was later moved to support modules.</p>
  
  <div style="max-width: 500px; margin: 0 auto;">
    <p style="margin: 12px 0;">
      <a href="https://novaflare.fun" style="font-size: 1.1em; display: block;">🌐 Our Official Website 🌐</a>
    </p>
    <p style="margin: 12px 0;">
      <a href="https://novaflare.fun/docs-choose.html" style="font-size: 1.1em; display: block;">❗Our Docs❗</a>
    </p>
  </div>
</div>
<br />

# Introduction
The FNF-NovaFlare-Engine was originally created to be compatible with the Camellia mod, and it has continuously evolved into an independent engine, developed by Chinese developers. 

V1.0.1 is based on FNF-Psych-Engine-0.6.3.
V1.1.0-beta-1 and above are based on 0.7.3.
V1.1.8-HOTFIX is based on 0.7.3 and supports mods version 1.0.0 and above (partially).
v1.2.1: Minimum support **Psych mod 0.7.3 to 1.0.4**, **V-Slice 0.8.4**, **CodeName 1.0.1**

Highly optimize a large number of pending issues, including but not limited to frame rate improvement, loading optimization, major overhauls of the underlying system, and script system overhauls...  
Add more practical features and beautify the interface.  

~~Make your device stronger, more awesome, more invincible, more frequent, more ridiculous, more despair-inducing, and more frustratingly prone to crashes.~~

# Function
## Hscript Upgrade

Starting from NovaFlare 1.2.0, Hscript has been upgraded to Hscript--iris-improved. This update brings script syntax closer to actual source code, with support for `class` and `package`.

## Performance Improvements

- The first TPS frame count has exceeded 1000.
- Thread separation for rendering has been implemented for the first time.
- Immix GC optimization reduces lag during gameplay.

## Interface and Underlying Updates

- The freeplay option interface has been rewritten for a better visual experience.
- The underlying Haxelib has been fully upgraded, with added recording and replay features.

## Miscellaneous

- ~~All open staff members of NF are Chinese (though this is not particularly relevant).~~

**You'll need to explore more features on your own.**

**[For more info, check out the release](https://github.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/releases)**

# Notes!!!!
## Open Source Usage

We welcome everyone to use our open-source code, **but please ensure that proper credit is given to the original source.**

## About the "private" Directory

The `private` directory in this repository is used for integrating NovaFlare with [GameAnalytics](https://www.gameanalytics.com) to collect usage data from our staff. It is not made public because it contains sensitive API keys, and we require real data for internal purposes.

[You can use now](https://github.com/NovaFlare-Engine-Concentration/Gameanalytics-haxe/tree/main)

## CNE Mod Support

Our support for the CNE mod has **been officially approved by the CNE development team**. For detailed information, please refer to the "Usage Info" section in the CNE repository's [README](https://github.com/CodenameCrew/CodenameEngine/blob/main/README.md) . [Click here for more information](https://github.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/releases/tag/V1.2.1).


# NovaFlare crew credits:
| Avatar | Username | Involvement |
| ------ | -------- | ----------- | 
| ![](https://avatars.githubusercontent.com/u/105789304?v=4) | [NF Beihu](https://youtube.com/@beihu235) | Creator and programmer for NF (NovaFlare) Engine.
| ![](https://avatars.githubusercontent.com/u/166735337?s=400&u=90192fb223fa071ae4cfcfec0853ea7593f9d13d&v=4) |[MaoPou](https://github.com/MaoPou) | Helper and programmer for NF (NovaFlare) Engine.
| ![](https://raw.githubusercontent.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/refs/heads/main/assets/shared/images/credits/bigIcon/chiny.png) |[Chiny](https://space.bilibili.com/3493288327777064) | Programmer for NF (NovaFlare) Engine and Touhou player.
| ![](https://raw.githubusercontent.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/refs/heads/main/assets/shared/images/credits/bigIcon/tieguo.png) |[TieGuo](https://b23.tv/7OVWzAO) | Pause menu redesigner for NF (NovaFlare) Engine.
| ![](https://raw.githubusercontent.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/refs/heads/main/assets/shared/images/credits/bigIcon/Careful_Scarf_487.png) |[Careful_Scarf_487](https://b23.tv/DQ1a0jO) | Main artist for NF (NovaFlare) Engine.
| ![](https://raw.githubusercontent.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/refs/heads/main/assets/shared/images/credits/bigIcon/mengqi.png) |[MengQi](https://space.bilibili.com/2130239542) | Artist for NF's pause menu.
| ![](https://raw.githubusercontent.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/refs/heads/main/assets/shared/images/credits/bigIcon/AZjessica.png) |[AZjessica](https://www.youtube.com/@azjessica) | Freeplay menu artist for NF (NovaFlare) Engine.
| ![](https://raw.githubusercontent.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/refs/heads/main/assets/shared/images/credits/bigIcon/beneyre.png) |[Ben Eyre](https://x.com/hngstngxng83905?t=GDKWYMRZsCMUMXYs0cmYrw&s=09) | Credits menu artist for NF (NovaFlare) Engine.
| ![](https://raw.githubusercontent.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/refs/heads/main/assets/shared/images/credits/als.png) |[Als](https://b23.tv/mNNX8R8) | Init intro artist for NF (NovaFlare) Engine.
| ![](https://raw.githubusercontent.com/NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine/refs/heads/main/assets/shared/images/credits/bigIcon/ddd.png) |[blockDDDdark](https://space.bilibili.com/401733211) | Engine sound effort helper for NF (NovaFlare) Engine.

# Psych Engine credits
| Avatar | Username | Involvement |
| ------ | -------- | ----------- |
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/shadowmario.png) | [Shadow Mario](https://ko-fi.com/shadowmario) | Main programmer and Head of Psych Engine
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/riveren.png) | [Riveren](https://x.com/riverennn) | Main Artist/Animator of Psych Engine
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/bb.png) | [Bb-Panzu](https://x.com/bbsub3) | Ex-programmer of Psych Engine
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/crowplexus.png) | [Crowplexus](https://twitter.com/IamMorwen) | Linux Support, HScript Iris, Input System v3, and Other PRs
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/kamizeta.png) | [Kamizeta](https://www.instagram.com/cewweey/) | Creator of Pessy, Psych Engine's mascot
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/maxneton.png) | [MaxNeton](https://bsky.app/profile/maxneton.bsky.social) | Loading Screen Easter Egg Artist/Animator
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/keoiki.png) | [Keoiki](https://x.com/Keoiki_) | Note Splash Animations and Latin Alphabet
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/sqirra.png) | [SqirraRNG](https://x.com/gedehari) | Crash Handler and Base code for Chart Editor's Waveform
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/mastereric.png) | [EliteMasterEric](https://x.com/EliteMasterEric) | Runtime Shaders support and Other PRs"
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/majigsaw.png) | [MAJigsaw](https://x.com/MAJigsaw77) | MP4 Video Loader Library (hxvlc)
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/flicky.png) | [iFlicky](https://x.com/flicky_i) | Composer of Psync and Tea Time and some sound effects
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/kade.png) | [KadeDev](https://x.com/kade0912) | Fixed some issues on Chart Editor and Other PRs
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/superpowers04.png) | [Superpowers04](https://x.com/superpowers04) | LUA JIT fork contributor
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/cheems.png) | [CheemsAndFriends](https://x.com/CheemsnFriendos) | Creator of FlxAnimate lib

# Funkin Crew credits
| Avatar | Username | Involvement |
| ------ | -------- | ----------- |
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/ninjamuffin99.png) | [NinjaMuffin99](https://x.com/ninja_muffin99) | Programmer of Friday Night Funkin'
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/phantomarcade.png) | [PhantomArcade](https://x.com/PhantomArcade3K) | Animator of Friday Night Funkin'
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/evilsk8r.png) | [Evilsk8r](https://x.com/evilsk8r) | Artist of Friday Night Funkin'
| ![](https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/refs/heads/main/assets/shared/images/credits/kawaisprite.png) | [KawaiSprite](https://x.com/kawaisprite) | Composer of Friday Night Funkin'
