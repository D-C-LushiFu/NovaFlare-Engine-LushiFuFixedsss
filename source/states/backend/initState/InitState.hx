package states.backend.initState;

import sys.thread.Thread;

import lime.app.Application;
import lime.system.System as LimeSystem;
import lime.graphics.opengl.GL;
import lime.graphics.Image;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.events.KeyboardEvent;

import flixel.input.gamepad.FlxGamepad;

import states.storyMenuState.StoryMenuState;
import states.backend.flashingState.FlashingState;
import states.backend.outdatedState.OutdatedState;
import states.mainMenuState.MainMenuState;
import states.freeplayState.FreeplayState;
import states.titleState.TitleState;

import scripts.init.InitScriptData;

import mobile.objects.EditorMobileKeys;
import mobile.server.EditorKeyServer;

import general.shaders.ColorblindFilter;
import gameanalytics.GABridge;

import games.backend.WeekData;
import games.backend.Highscore;
import games.backend.Song;

#if mobile
import mobile.states.CopyState;
#end

#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
#end

#if android
import general.backend.device.AppData;
import states.backend.pirateState.PirateState;
#end

class InitState extends MusicBeatState
{
	var skipVideo:FlxText;

	var mustUpdate:Bool = false;

	public static var updateVersion:String = '';

	public static var ignoreCopy = false; //用于copystate，别删

	override public function create()
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		@:privateAccess {
			if (FlxG.game.stage != null && FlxG.game.stage.window != null)
				FlxG.game.stage.window.frameRate = FlxG.updateFramerate;
		}
		FlxG.keys.preventDefaultKeys = [TAB];

		super.create();

		// `FlxSave.bind()` clears the current `data` up-front and only fills it back in
		// when the shared object loads successfully, so a save file that fails to parse
		// (or to read) leaves `FlxG.save.data == null`. Reading any field of that null
		// Dynamic is a hard access violation on hxcpp, which used to kill the engine
		// before the first frame. Give flixel a recovery parser and then make sure the
		// container is never left null.
		FlxG.save.bind('funkin', CoolUtil.getSavePath(), ClientPrefs.recoverUnreadableSave);
		ClientPrefs.ensureSaveData();

		ClientPrefs.loadPrefs();

		// 调试/自动化验证用：启动参数 -emk / --emk / emk 或环境变量 NOVAF_EMK=1
		// 等效于在维护设置里打开「调整移动端各Editor键位」（不弹浏览器）。
		#if sys
		try
		{
			var argHit:Bool = Sys.args().indexOf('-emk') != -1 || Sys.args().indexOf('--emk') != -1 || Sys.args().indexOf('emk') != -1;
			var envHit:Bool = false;
			try { envHit = Sys.getEnv('NOVAF_EMK') == '1'; } catch (e:Dynamic) {}
			if (argHit || envHit)
				EditorMobileKeys.setEnabled(true, false);
		}
		catch (e:Dynamic) {}
		#end

		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		GABridge.init();

		switch (ClientPrefs.data.gameQuality)
		{
			case 0:
				FlxG.game.stage.quality = openfl.display.StageQuality.LOW;
			case 1:
				FlxG.game.stage.quality = openfl.display.StageQuality.HIGH;
			case 2:
				FlxG.game.stage.quality = openfl.display.StageQuality.MEDIUM;
			case 3:
				FlxG.game.stage.quality = openfl.display.StageQuality.BEST;
		}

		#if mobile
		FlxG.fullscreen = true;
		#end

		#if desktop FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, Main.toggleFullScreen); #end

		#if android FlxG.android.preventDefaultKeys = [BACK]; #end

		#if mobile
		LimeSystem.allowScreenTimeout = ClientPrefs.data.screensaver;
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		// shader coords fix
		FlxG.signals.gameResized.add(function(w, h)
		{
			if (FlxG.cameras != null)
			{
				for (cam in FlxG.cameras.list)
				{
					if (cam != null && cam.filters != null)
						Main.resetSpriteCache(cam.flashSprite);
				}
			}

			if (FlxG.game != null)
				Main.resetSpriteCache(FlxG.game);
		});		

		var maxTextureSize:Int = GL.getParameter(GL.MAX_TEXTURE_SIZE);
		trace('maxTextureSize: ' + maxTextureSize);
		Image.setMaxTextureSize(maxTextureSize);

		trace("GL_VENDOR=" + GL.getString(GL.VENDOR));
		trace("GL_RENDERER=" + GL.getString(GL.RENDERER));
		trace("GL_VERSION=" + GL.getString(GL.VERSION));

		Language.resetData();

		originfunkin.OriginFunkinConfig.setStartVideoEnabled(ClientPrefs.data.skipTitleVideo ? false : true);

		#if CHECK_FOR_UPDATES
		if (ClientPrefs.data.checkForUpdates)
		{
			var thread = Thread.create(() ->
        	{
				try
				{
					trace('checking for update');
					// 版本检查必须指向本分支(修复版)自己的仓库，而不是已经停止维护的上游仓库
					var http = new haxe.Http("https://raw.githubusercontent.com/D-C-LushiFu/NovaFlare-Engine-LushiFuFixedsss/refs/heads/main/gitVersion.txt");

					http.onData = function(data:String)
					{
						try
						{
							// gitVersion.txt：第 1 行 = 引擎版本号(如 1.2.1)，第 2 行 = 数据版本号(如 2.9)
							var lines:Array<String> = data.split('\n');
							var onlineEngineLine:String = (lines.length > 0 ? lines[0] : '').trim();
							var onlineDataLine:String = (lines.length > 1 ? lines[1] : '').trim();
							var onlineEngine:Float = toVersionNumber(onlineEngineLine);
							var onlineData:Float = toVersionNumber(onlineDataLine);
							var localEngine:Float = toVersionNumber(MainMenuState.novaFlareEngineVersion);
							var localData:Float = toVersionNumber(Std.string(MainMenuState.novaFlareEngineDataVersion));

							trace('version online: ' + onlineEngineLine + ', your version: ' + MainMenuState.novaFlareEngineVersion);

							if (onlineEngine > localEngine || onlineData > localData)
							{
								trace('versions arent matching!');
								updateVersion = (onlineEngine > localEngine ? onlineEngineLine : onlineDataLine);
								TitleState.updateVersion = updateVersion;
								mustUpdate = true;
							}
						}
						catch (e:Dynamic)
						{
							// 解析失败不能影响游戏，只记录日志
							trace('update check parse error: $e');
						}
					}

					http.onError = function(error)
					{
						trace('update check error: $error');
					}

					http.request();
				}
				catch (e:Dynamic)
				{
					// 更新检查里的任何异常都绝不能让整个程序崩溃，只记录日志
					trace('update check exception: $e');
				}
			});
		}
		#end

		#if mobile
		if (ClientPrefs.data.filesCheck && !ignoreCopy)
		{
			if (!CopyState.checkExistingFiles())
			{
				FlxG.switchState(new CopyState());
				return;
			}
		}
		ignoreCopy = false;

        // 检查assets/version.txt存不存在且里面保存的上一个版本号与当前的版本号一不一致，如果不一致或不存在，强制启动copy。
        if (!FileSystem.exists(Paths.getSharedPath('version.txt')))
        {
            sys.io.File.saveContent(Paths.getSharedPath('version.txt'), 'now version: ' + Std.string(states.mainMenuState.MainMenuState.novaFlareEngineVersion) + '\n' + 'commit: ' + Std.string(states.mainMenuState.MainMenuState.novaFlareEngineCommit));
            FlxG.switchState(new CopyState(true));
            return;
        }
        else
        {
            var expectedContent = 'now version: ' + Std.string(states.mainMenuState.MainMenuState.novaFlareEngineVersion) + '\n' + 'commit: ' + Std.string(states.mainMenuState.MainMenuState.novaFlareEngineCommit);
            var actualContent = sys.io.File.getContent(Paths.getSharedPath('version.txt'));
            
            if (actualContent != expectedContent)
            {
                sys.io.File.saveContent(Paths.getSharedPath('version.txt'), expectedContent);
                FlxG.switchState(new CopyState(true));
                return;
            }
        }

		#end

		Highscore.load();

		#if LUA_ALLOWED
		#if (android && EXTERNAL || MEDIA)
		try
		{
		#end
			Mods.pushGlobalMods();
		#if (android && EXTERNAL || MEDIA)
		}
		catch (e:Dynamic)
		{
			SUtil.showPopUp("permission is not obtained, restart the application", "Error!");
			Sys.exit(1);
		}
		#end
		#end

		Mods.loadTopMod();

		// 窗口固定以默认窗口化启动（不再从存档恢复全屏/旧窗口状态，
		// 避免旧存档数据把窗口状态“污染”成奇怪的全屏/尺寸）
		persistentUpdate = true;
		persistentDraw = true;

		InitScriptData.init();
		Main.initScriptModules();
		#if HSCRIPT_ALLOWED
		scripts.stages.modules.ModuleHandler.init();
		scripts.stages.GlobalHandler.init();
		#end

		ColorblindFilter.UpdateColors();
	
		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		#if sys
		if (startDiagnosticGameplay())
			return;
		#end
	
		FlxG.mouse.visible = false;
		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if (FlxG.save.data.openedFlash == null)
		{
			FlxG.save.data.openedFlash = true;
			//ClientPrefs.saveSettings();
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else
		{
			startCutscenesIn();
		}
		#end
	}

	#if sys
	function startDiagnosticGameplay():Bool
	{
		var requestedSong:String = Sys.getEnv('NOVAFLARE_DIAGNOSTIC_SONG');
		if (requestedSong == null || requestedSong.trim().length == 0)
			return false;

		requestedSong = Paths.formatToSongPath(requestedSong.trim());

		var requestedMod:String = Sys.getEnv('NOVAFLARE_DIAGNOSTIC_MOD');
		if (requestedMod != null && requestedMod.trim().length > 0)
			Mods.currentModDirectory = requestedMod.trim();

		Difficulty.resetList();
		var difficulty:Int = 1;
		var requestedDifficulty:String = Sys.getEnv('NOVAFLARE_DIAGNOSTIC_DIFFICULTY');
		if (requestedDifficulty != null && requestedDifficulty.trim().length > 0)
		{
			var requestedDifficultyValue:String = requestedDifficulty.trim();
			var parsedDifficulty:Null<Int> = Std.parseInt(requestedDifficultyValue);
			if (parsedDifficulty != null)
				difficulty = parsedDifficulty;
			else
			{
				Difficulty.copyFrom([requestedDifficultyValue]);
				difficulty = 0;
			}
		}
		difficulty = Std.int(Math.max(0, Math.min(Difficulty.list.length - 1, difficulty)));

		var botplayValue:String = Sys.getEnv('NOVAFLARE_DIAGNOSTIC_BOTPLAY');
		var botplay:Bool = botplayValue == null
			|| !['0', 'false', 'off', 'no'].contains(botplayValue.trim().toLowerCase());

		try
		{
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = difficulty;
			PlayState.replayMode = false;
			PlayState.chartingMode = false;
			PlayState.changedDifficulty = false;
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = true;
			PlayState.startOnTime = 0;
			ClientPrefs.data.gameplaySettings.set('practice', false);
			ClientPrefs.data.gameplaySettings.set('botplay', botplay);
			if (FlxG.sound.music == null)
				FlxG.sound.playMusic(Paths.music('none'), 0, true);

			var chartName:String = Highscore.formatSong(requestedSong, difficulty);
			PlayState.SONG = Song.loadFromJson(chartName, requestedSong);
			trace('diagnostic:gameplay prepared song=$requestedSong chart=$chartName '
				+ 'difficulty=$difficulty mod=${Mods.currentModDirectory} botplay=$botplay');

			LoadingState.prepareToSong();
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			LoadingState.loadAndSwitchState(new PlayState());
			return true;
		}
		catch (error:Dynamic)
		{
			trace('diagnostic:gameplay error=$error stack=${haxe.CallStack.exceptionStack()}');
			throw error;
		}
	}
	#end
	
	function startCutscenesIn()
	{
		if (!ClientPrefs.data.skipTitleVideo)
			#if VIDEOS_ALLOWED
			startVideo('menuExtend/titleIntro');
			#else
			changeState();
			#end
		else
			changeState();
	}
	
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
			
		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;
	
		#if ios
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end
	
		#if android
		if (FlxG.android.justReleased.BACK)
			pressedEnter = true;
		#end
	
		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;
	
		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;
	
			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}
		
		if (pressedEnter)
		{
			#if VIDEOS_ALLOWED
			if (video != null && !videoFinished)
				videoEnd();
			else
				changeState();
			#else
			changeState();
			#end
			return;
		}
	
		super.update(elapsed);
	}
	
	#if VIDEOS_ALLOWED
	var video:FlxVideoSprite;
	var videoFinished:Bool = false;
	var videoHasFrame:Bool = false;
	var videoWatchdog:FlxTimer;
	
	function startVideo(name:String)
	{
		videoFinished = false;
		videoHasFrame = false;
		skipVideo = new FlxText(0, FlxG.height - 26, 0, "Press " + #if android "Back on your Phone " #else "Enter " #end + "to skip", 18);
		skipVideo.setFormat(Assets.getFont("assets/fonts/montserrat.ttf").fontName, 18);
		skipVideo.alpha = 0;
		skipVideo.alignment = CENTER;
		skipVideo.screenCenter(X);
		skipVideo.scrollFactor.set();
		skipVideo.antialiasing = ClientPrefs.data.antialiasing;
	
		#if VIDEOS_ALLOWED
		var filepath:String = Paths.video(name);
		#if sys
		if (!FileSystem.exists(filepath))
		#else
		if (!OpenFlAssets.exists(filepath))
		#end
		{
			FlxG.log.warn('Couldnt find video file: ' + name);
			videoEnd();
			return;
		}
	
		video = new FlxVideoSprite(0, 0);
		video.antialiasing = true;
		if (!ClientPrefs.data.useFlixelCoords)
		{
			video.bitmap.x -= FlxG.game.x;
			video.bitmap.y -= FlxG.game.y;
		}
		video.bitmap.onFormatSetup.add(function():Void
		{
			if (video.bitmap != null && video.bitmap.bitmapData != null)
			{
				final scale:Float = Math.min(FlxG.width / video.bitmap.bitmapData.width, FlxG.height / video.bitmap.bitmapData.height);
	
				video.setGraphicSize(video.bitmap.bitmapData.width * scale, video.bitmap.bitmapData.height * scale);
				video.updateHitbox();
				video.screenCenter();
			}
		});
		video.bitmap.onEndReached.add(videoEnd);
		video.bitmap.onEncounteredError.add(function(message:String):Void
		{
			FlxG.log.error('Video playback failed: ' + message);
			videoEnd();
		});
		video.bitmap.onDisplay.add(function():Void
		{
			if (videoHasFrame)
				return;
			videoHasFrame = true;
			if (videoWatchdog != null)
			{
				videoWatchdog.cancel();
				videoWatchdog = null;
			}
		});
		add(video);
		if (!video.load(filepath))
		{
			FlxG.log.warn('Couldnt load video file: ' + filepath);
			videoEnd();
			return;
		}
		new FlxTimer().start(0.001, function(_):Void
		{
			if (video != null && video.bitmap != null && FlxG.state == this)
			{
				if (!video.play())
				{
					FlxG.log.error('Video player refused to start: ' + filepath);
					videoEnd();
					return;
				}
				if (!videoHasFrame)
				{
					videoWatchdog = new FlxTimer().start(8, function(_):Void
					{
						if (!videoFinished && !videoHasFrame && FlxG.state == this)
						{
							FlxG.log.error('Video produced no display frame: ' + filepath);
							videoEnd();
						}
					});
				}
			}
		});
	
		showText();
		#else
		FlxG.log.warn('Platform not supported!');
		videoEnd();
		return;
		#end
	}
	
	function videoEnd()
	{
		if (videoFinished)
			return;
		videoFinished = true;
		if (videoWatchdog != null)
		{
			videoWatchdog.cancel();
			videoWatchdog = null;
		}
		if (skipVideo != null) skipVideo.visible = false;
		var oldVideo:FlxVideoSprite = video;
		video = null;
		if (oldVideo != null) {
			if (oldVideo.bitmap != null)
				oldVideo.bitmap.onEndReached.remove(videoEnd);
			oldVideo.stop();
			remove(oldVideo, true);
			oldVideo.destroy();
		}
		changeState();
		trace("end");
	}
	
	function showText()
	{
		add(skipVideo);
		FlxTween.tween(skipVideo, {alpha: 1}, 1, {ease: FlxEase.quadIn});
		FlxTween.tween(skipVideo, {alpha: 0}, 1, {ease: FlxEase.quadIn, startDelay: 4});
	}
	#end

	var changingState:Bool = false;

	/**
	 * 把版本号字符串(如 "1.2.1"、"2.9")转成可比较的数字，最多支持 3 段。
	 * 解析失败时返回 NaN，任何比较结果都为 false，不会误报更新。
	 */
	static function toVersionNumber(value:String):Float
	{
		if (value == null)
			return Math.NaN;

		var parts:Array<String> = value.split('.');
		var result:Float = 0;
		var weight:Float = 1000000;
		var parsed:Bool = false;

		for (i in 0...3)
		{
			if (i >= parts.length)
				break;

			var part:Null<Int> = Std.parseInt(parts[i]);
			if (part == null || part < 0)
				break;

			result += part * weight;
			weight /= 1000;
			parsed = true;
		}

		return parsed ? result : Math.NaN;
	}

	function changeState() {
		if (changingState)
			return;
		changingState = true;
		if (mustUpdate && !OutdatedState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new OutdatedState());
		}
		else
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new TitleState());
		}
	}
}
