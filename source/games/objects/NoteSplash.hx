package games.objects;

import flixel.system.FlxAssets.FlxShader;

import general.backend.animation.PsychAnimationController;
import general.backend.Cache;

import general.shaders.RGBPalette;
import general.shaders.ColorSwap;

import games.backend.ExtraKeysHandler;

typedef RGB = {
	r:Null<Int>,
	g:Null<Int>,
	b:Null<Int>
}

typedef NoteSplashAnim = {
	name:String,
	noteData:Int,
	prefix:String,
	indices:Array<Int>,
	offsets:Array<Float>,
	fps:Array<Int>
}

typedef NoteSplashConfig = {
	animations:Map<String, NoteSplashAnim>,
	scale:Float,
	allowRGB:Bool,
	allowPixel:Bool,
	rgb:Array<Null<RGB>>
}

class NoteSplash extends FlxSprite
{
	public var rgbShader:PixelSplashShaderRef;
	public var colorSwap:ColorSwap = null;
	public var texture:String;
	public var config(default, set):NoteSplashConfig;
	public var babyArrow:StrumNote;
	public var noteData:Int = 0;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var inEditor:Bool = false;

	var spawned:Bool = false;
	var noteDataMap:Map<Int, String> = new Map();
	var animStride:Int = 4; // how many "lanes" a full anim set spans (4 = default, 10 = NovaFlare Extra Keys)
	var maniaScale:Float = 1; // NovaFlare Extra Keys: per-mania splash scale factor

	public static var defaultNoteSplash(default, never):String = 'noteSplashes/noteSplashes';
	public static var configs:Map<String, NoteSplashConfig> = new Map<String, NoteSplashConfig>();

	static var oldPath:Bool = false;

	/** NovaFlare: legacy 0.7-style mods keep a plain noteSplashes.png at the images root */
	public static function init()
	{
		oldPath = Paths.fileExists('images/noteSplashes.png', IMAGE);
	}

	/** NovaFlare Extra Keys: lane -> color name used inside the splash XML (falls back to the default 4 lanes) */
	public static function laneNoteNames():Array<String>
	{
		var ek:ExtraKeysHandler = ExtraKeysHandler.instance;
		if (ek != null && ek.data != null && ek.data.animations != null && ek.data.animations.length > 0)
			return [for (i in 0...ek.data.animations.length) ek.data.animations[i].note];
		return Note.colArray.copy();
	}

	public static function laneCount():Int
	{
		return laneNoteNames().length;
	}

	public function new(?x:Float = 0, ?y:Float = 0, ?splash:String)
	{
		super(x, y);

		animation = new PsychAnimationController(this);

		rgbShader = new PixelSplashShaderRef();

		// NovaFlare: note color swap support
		if (ClientPrefs.data.noteColorSwap)
		{
			colorSwap = new ColorSwap();
			shader = colorSwap.shader;
		}
		else
			shader = rgbShader.shader;

		loadSplash(splash);
	}

	public var maxAnims(default, set):Int = 0;
	public function loadSplash(?splash:String)
	{
		config = null;
		maxAnims = 0;

		if(splash == null)
		{
			splash = defaultNoteSplash + getSplashSkinPostfix();
			if (PlayState.SONG != null && PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) splash = PlayState.SONG.splashSkin;
			else if (oldPath && ClientPrefs.data.splashSkin == ClientPrefs.defaultData.splashSkin) splash = 'noteSplashes'; // NovaFlare legacy mods
		}

		// NovaFlare: Extra Keys per-mania scale factor
		maniaScale = 1;
		var ek:ExtraKeysHandler = ExtraKeysHandler.instance;
		if (ek != null && ek.data != null && ek.data.scales != null && PlayState.SONG != null && PlayState.SONG.mania >= 0 && PlayState.SONG.mania < ek.data.scales.length)
			maniaScale = ek.data.scales[PlayState.SONG.mania] + 0.3;

		texture = splash;
		if (!loadFramesCached(texture))
		{
			texture = defaultNoteSplash + getSplashSkinPostfix();
			if (!loadFramesCached(texture))
			{
				texture = defaultNoteSplash;
				loadFramesCached(texture);
			}
		}

		var path:String = 'images/$texture';
		if (configs.exists(path))
		{
			this.config = configs.get(path);
			return;
		}
		else if (Paths.fileExists('$path.json', TEXT))
		{
			var config:Dynamic = haxe.Json.parse(Paths.getTextFromFile('$path.json'));
			if (config != null)
			{
				var tempConfig:NoteSplashConfig = {
					animations: new Map(),
					scale: config.scale,
					allowRGB: config.allowRGB,
					allowPixel: config.allowPixel,
					rgb: config.rgb
				}

				for (i in Reflect.fields(config.animations))
				{
					var anim:NoteSplashAnim = Reflect.field(config.animations, i);
					tempConfig.animations.set(i, anim);
				}

				this.config = tempConfig;
				configs.set(path, this.config);
				return;
			}
		}

		// Splashes with no json: build from the XML (and a legacy 0.7-style .txt when present)
		var tempConfig:NoteSplashConfig = createConfig();
		var anim:String = 'note splash';
		var fps:Array<Null<Int>> = [22, 26];
		var offsets:Array<Array<Float>> = [[0, 0]];
		if (Paths.fileExists('$path.txt', TEXT)) // Backwards compatibility with 0.7 splash txts
		{
			var configFile:Array<String> = CoolUtil.coolTextFile(Paths.getPath('$path.txt', TEXT, true));
			if (configFile.length > 0)
			{
				anim = configFile[0];
				if (configFile.length > 1)
				{
					var framerates:Array<String> = configFile[1].split(' ');
					fps = [Std.parseInt(framerates[0]), Std.parseInt(framerates[1])];
					if (fps[0] == null) fps[0] = 22;
					if (fps[1] == null) fps[1] = 26;

					if (configFile.length > 2)
					{
						offsets = [];
						for (i in 2...configFile.length)
						{
							if (configFile[i].trim() != '')
							{
								var animOffs:Array<String> = configFile[i].split(' ');
								var x:Float = Std.parseFloat(animOffs[0]);
								var y:Float = Std.parseFloat(animOffs[1]);
								if (Math.isNaN(x)) x = 0;
								if (Math.isNaN(y)) y = 0;
								offsets.push([x, y]);
							}
						}
					}
				}
			}
		}

		if (offsets.length < 1)
			offsets = [[0, 0]];

		// NovaFlare: discovery walks every Extra Keys lane (default XMLs recycle the 4 base colors)
		var lanes:Array<String> = laneNoteNames();
		var laneAmt:Int = lanes.length;

		var foundSets:Int = 0;
		while (true)
		{
			var failedToFind:Bool = false;
			for (lane in 0...laneAmt)
			{
				if (!checkForAnim('$anim ${lanes[lane]} ${foundSets + 1}'))
				{
					failedToFind = true;
					break;
				}
			}
			if (failedToFind) break;
			foundSets++;
		}

		for (set in 0...foundSets)
		{
			for (lane in 0...laneAmt)
			{
				var data:Int = lane + (set * laneAmt);
				var offset:Array<Float> = offsets[FlxMath.wrap(lane + (set * Note.colArray.length), 0, Std.int(offsets.length - 1))];
				addAnimationToConfig(tempConfig, 1, 'note$lane-${set + 1}', '$anim ${lanes[lane]} ${set + 1}', fps, offset, [], data);
			}
		}

		this.config = tempConfig;
		configs.set(path, this.config);
	}

	/** NovaFlare: route atlas loading through the engine-wide frame cache */
	function loadFramesCached(skin:String):Bool
	{
		if (!Cache.checkFrame(skin))
			Cache.setFrame(skin, {graphic: null, frame: Paths.getSparrowAtlas(skin, null, false)});
		frames = Cache.getFrame(skin);
		return frames != null;
	}

	public function spawnSplashNote(?x:Float = 0, ?y:Float = 0, ?noteData:Int = 0, ?note:Note, ?randomize:Bool = true)
	{
		if (note != null && note.noteSplashData.disabled)
			return;

		aliveTime = 0;

		if (!inEditor)
		{
			var loadedTexture:String = defaultNoteSplash + getSplashSkinPostfix();
			if (note != null && note.noteSplashData.texture != null) loadedTexture = note.noteSplashData.texture;
			else if (PlayState.SONG != null && PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) loadedTexture = PlayState.SONG.splashSkin;

			if (texture != loadedTexture) loadSplash(loadedTexture);
		}

		setPosition(x, y);

		if (babyArrow != null)
			setPosition(babyArrow.x - Note.swagWidth * 0.95, babyArrow.y - Note.swagWidth); // To prevent it from being misplaced for one game tick

		if (note != null)
			noteData = note.noteData;

		if (randomize && maxAnims > 1)
			noteData = (noteData % animStride) + (FlxG.random.int(0, maxAnims - 1) * animStride);

		this.noteData = noteData;
		var anim:String = playDefaultAnim();

		var tempShader:RGBPalette = null;
		if (config.allowRGB)
		{
			Note.initializeGlobalRGBShader(noteData % Note.colArray.length);
			if (inEditor || (note == null || note.noteSplashData.useRGBShader) && (PlayState.SONG == null || !PlayState.SONG.disableNoteRGB))
			{
				tempShader = new RGBPalette();
				// If Note RGB is enabled:
				if ((note == null || !note.noteSplashData.useGlobalShader) || inEditor)
				{
					var colors = config.rgb;
					if (colors != null)
					{
						for (i in 0...colors.length)
						{
							if (i > 2) break;

							var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[noteData % Note.colArray.length];
							if (PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[noteData % Note.colArray.length];

							var rgb = colors[i];
							if (rgb == null)
							{
								if (i == 0) tempShader.r = arr[0];
								else if (i == 1) tempShader.g = arr[1];
								else if (i == 2) tempShader.b = arr[2];
								continue;
							}

							var r:Null<Int> = rgb.r;
							var g:Null<Int> = rgb.g;
							var b:Null<Int> = rgb.b;

							if (r == null || Math.isNaN(r) || r < 0) r = arr[0];
							if (g == null || Math.isNaN(g) || g < 0) g = arr[1];
							if (b == null || Math.isNaN(b) || b < 0) b = arr[2];

							var color:FlxColor = FlxColor.fromRGB(r, g, b);
							if (i == 0) tempShader.r = color;
							else if (i == 1) tempShader.g = color;
							else if (i == 2) tempShader.b = color;
						}
					}
					else
					{
						// NovaFlare's RGBPalette has no copyValues: copy the default lane colors manually
						var rgbShit:RGBPalette = Note.globalRgbShaders[noteData % Note.colArray.length];
						if (rgbShit != null)
						{
							tempShader.r = rgbShit.r;
							tempShader.g = rgbShit.g;
							tempShader.b = rgbShit.b;
							tempShader.mult = rgbShit.mult;
						}
					}

					if (note != null)
					{
						if (note.noteSplashData.r != -1) tempShader.r = note.noteSplashData.r;
						if (note.noteSplashData.g != -1) tempShader.g = note.noteSplashData.g;
						if (note.noteSplashData.b != -1) tempShader.b = note.noteSplashData.b;
					}
				}
				else
				{
					// NovaFlare's RGBPalette has no copyValues: copy the default lane colors manually
					var rgbShit:RGBPalette = Note.globalRgbShaders[noteData % Note.colArray.length];
					if (rgbShit != null)
					{
						tempShader.r = rgbShit.r;
						tempShader.g = rgbShit.g;
						tempShader.b = rgbShit.b;
						tempShader.mult = rgbShit.mult;
					}
				}
			}
		}
		rgbShader.copyValues(tempShader);
		if (!config.allowPixel) rgbShader.pixelAmount = 1;
		else if (PlayState.isPixelStage) rgbShader.pixelAmount = PlayState.daPixelZoom;

		// NovaFlare: note color swap (hue/sat/brt from arrow HSV or the note's own values)
		if (colorSwap != null)
		{
			var hue:Float = ClientPrefs.data.arrowHSV[noteData % Note.colArray.length][0] / 360;
			var sat:Float = ClientPrefs.data.arrowHSV[noteData % Note.colArray.length][1] / 100;
			var brt:Float = ClientPrefs.data.arrowHSV[noteData % Note.colArray.length][2] / 100;

			if (note != null)
			{
				hue = note.noteSplashHue;
				sat = note.noteSplashSat;
				brt = note.noteSplashBrt;
			}

			colorSwap.hue = hue;
			colorSwap.saturation = sat;
			colorSwap.brightness = brt;
		}

		offset.set(10, 10);
		var conf:NoteSplashAnim = config.animations.get(anim);
		var offsets:Array<Float> = [0, 0];
		if (conf != null) offsets = conf.offsets;
		if (offsets != null)
		{
			offset.x += offsets[0] * maniaScale;
			offset.y += offsets[1] * maniaScale;
		}

		animation.finishCallback = function(name:String) {
			kill();
			spawned = false;
		}

		alpha = ClientPrefs.data.splashAlpha;
		if (note != null) alpha = note.noteSplashData.a;

		antialiasing = ClientPrefs.data.antialiasing;
		if (note != null) antialiasing = note.noteSplashData.antialiasing;
		if (PlayState.isPixelStage && config.allowPixel) antialiasing = false;

		var minFps:Int = 22;
		var maxFps:Int = 26;
		if (conf != null)
		{
			minFps = conf.fps[0];
			if (minFps < 0) minFps = 0;

			maxFps = conf.fps[1];
			if (maxFps < 0) maxFps = 0;
		}

		if (animation.curAnim != null)
			animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);

		spawned = true;
	}

	public function playDefaultAnim()
	{
		var anim:String = noteDataMap.get(noteData);
		if (anim != null && animation.exists(anim))
			animation.play(anim, true);

		return anim;
	}

	function checkForAnim(anim:String)
	{
		var animFrames = [];
		@:privateAccess
		animation.findByPrefix(animFrames, anim); // adds valid frames to animFrames

		return animFrames.length > 0;
	}

	var aliveTime:Float = 0;
	static var buggedKillTime:Float = 0.5; //automatically kills note splashes if they break to prevent it from flooding your HUD
	override function update(elapsed:Float)
	{
		if (spawned)
		{
			aliveTime += elapsed;
			if (animation.curAnim == null && aliveTime >= buggedKillTime)
			{
				kill();
				spawned = false;
			}
		}

		if (babyArrow != null)
		{
			if (copyX)
				x = babyArrow.x - Note.swagWidth * 0.95;

			if (copyY)
				y = babyArrow.y - Note.swagWidth;
		}
		super.update(elapsed);
	}

	public static function getSplashSkinPostfix()
	{
		var skin:String = '';
		if (ClientPrefs.data.splashSkin != ClientPrefs.defaultData.splashSkin)
			skin = '-' + ClientPrefs.data.splashSkin.trim().toLowerCase().replace(' ', '_');
		return skin;
	}

	public static function createConfig():NoteSplashConfig
	{
		return {
			animations: new Map(),
			scale: 1,
			allowRGB: true,
			allowPixel: true,
			rgb: null
		}
	}

	public static function addAnimationToConfig(config:NoteSplashConfig, scale:Float, name:String, prefix:String, fps:Array<Int>, offsets:Array<Float>, indices:Array<Int>, noteData:Int):NoteSplashConfig
	{
		if (config == null) config = createConfig();

		config.animations.set(name, {name: name, noteData: noteData, prefix: prefix, indices: indices, offsets: offsets, fps: fps});
		config.scale = scale;
		return config;
	}

	function set_config(value:NoteSplashConfig):NoteSplashConfig
	{
		if (value == null) value = createConfig();

		@:privateAccess
		animation.clearAnimations();
		noteDataMap.clear();
		maxAnims = 0;

		// NovaFlare: detect the legacy "note<lane>-<set>" naming so randomization matches its lane stride
		animStride = Note.colArray.length;
		for (i in value.animations)
		{
			if (i.name != null && ~/^note\d+-\d+$/.match(i.name))
			{
				animStride = laneCount();
				break;
			}
		}

		for (i in value.animations)
		{
			var key:String = i.name;
			if (i.prefix.length > 0 && key != null && key.length > 0)
			{
				if (i.indices != null && i.indices.length > 0)
					animation.addByIndices(key, i.prefix, i.indices, "", i.fps[1], false);
				else
					animation.addByPrefix(key, i.prefix, i.fps[1], false);

				noteDataMap.set(i.noteData, key);
				if (i.noteData % animStride == 0)
					maxAnims++;
			}
		}

		scale.set(value.scale * maniaScale, value.scale * maniaScale);
		return config = value;
	}

	function set_maxAnims(value:Int)
	{
		if (value > 0)
			noteData = Std.int(FlxMath.wrap(noteData, 0, (value * animStride) - 1));
		else
			noteData = 0;

		return maxAnims = value;
	}
}

class PixelSplashShaderRef
{
	public var shader:PixelSplashShader = new PixelSplashShader();
	public var enabled(default, set):Bool = true;
	public var pixelAmount(default, set):Float = 1;

	public function copyValues(tempShader:RGBPalette)
	{
		if (tempShader != null)
		{
			for (i in 0...3)
			{
				shader.r.value[i] = tempShader.shader.r.value[i];
				shader.g.value[i] = tempShader.shader.g.value[i];
				shader.b.value[i] = tempShader.shader.b.value[i];
			}
			shader.mult.value[0] = tempShader.shader.mult.value[0];
		}
		else enabled = false;
	}

	public function set_enabled(value:Bool)
	{
		enabled = value;
		shader.mult.value = [value ? 1 : 0];
		return value;
	}

	public function set_pixelAmount(value:Float)
	{
		pixelAmount = value;
		shader.uBlocksize.value = [value, value];
		return value;
	}

	public function reset()
	{
		shader.r.value = [0, 0, 0];
		shader.g.value = [0, 0, 0];
		shader.b.value = [0, 0, 0];
	}

	public function new()
	{
		reset();
		enabled = true;

		if (!PlayState.isPixelStage) pixelAmount = 1;
		else pixelAmount = PlayState.daPixelZoom;
	}
}

class PixelSplashShader extends FlxShader
{
	@:glFragmentHeader('
		#pragma header

		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;
		uniform vec2 uBlocksize;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec2 blocks = openfl_TextureSize / uBlocksize;
			vec4 color = flixel_texture2D(bitmap, floor(coord * blocks) / blocks);
			if (!hasTransform) {
				return color;
			}

			if (color.a == 0.0 || mult == 0.0) {
				return color * openfl_Alphav;
			}

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;

			color = mix(color, newColor, mult);

			if (color.a > 0.0) {
				return vec4(color.rgb, color.a);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}')

	@:glFragmentSource('
		#pragma header

		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')

	public function new()
	{
		super();
	}
}
