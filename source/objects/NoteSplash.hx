package objects;

import shaders.RGBPalette;
import flixel.system.FlxAssets.FlxShader;
import flixel.graphics.frames.FlxFrame;

typedef NoteSplashConfig = {
	anim:String,
	minFps:Int,
	maxFps:Int,
	offsets:Array<Array<Float>>
}

class NoteSplash extends FlxSprite
{
	public var rgbShader:RGBPalette = null;
	private var idleAnim:String;
	private var _textureLoaded:String = null;

	private static var defaultNoteSplash:String = 'noteSplashes/noteSplashes';
	public static var configs:Map<String, NoteSplashConfig> = new Map<String, NoteSplashConfig>();

	public function new(x:Float = 0, y:Float = 0) {
		super(x, y);

		var skin:String = null;
		if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) skin = PlayState.SONG.splashSkin;
		else skin = getSplashSkin();

		precacheConfig(skin);
		//setupNoteSplash(x, y, 0);
	}

	override function destroy()
	{
		configs.clear();
		super.destroy();
	}

	var maxAnims:Int = 2;
	public function setupNoteSplash(x:Float, y:Float, direction:Int = 0, ?note:Note = null) {
		setPosition(x - Note.swagWidth * 0.95, y - Note.swagWidth);
		aliveTime = 0;

		var texture:String = null;
		if(note != null && note.noteSplashData.texture != null) texture = note.noteSplashData.texture;
		else if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) texture = PlayState.SONG.splashSkin;
		else texture = getSplashSkin();
		
		var config:NoteSplashConfig = precacheConfig(texture);
		if(_textureLoaded != texture)
			config = loadAnims(texture, config);

		shader = null;
		if(note != null && !note.noteSplashData.useGlobalShader)
		{
			rgbShader = note.rgbShader.parent;
			if(note.noteSplashData.r != -1) rgbShader.r = note.noteSplashData.r;
			if(note.noteSplashData.g != -1) rgbShader.g = note.noteSplashData.g;
			if(note.noteSplashData.b != -1) rgbShader.b = note.noteSplashData.b;
			alpha = note.noteSplashData.a;
		}
		else
		{
			rgbShader = Note.globalRgbShaders[direction];
			alpha = 0.6;
		}

		if(note != null)
			antialiasing = note.noteSplashData.antialiasing;
		if(PlayState.isPixelStage) antialiasing = false;

		if(rgbShader != null) shader = rgbShader.shader;

		_textureLoaded = texture;
		offset.set(10, 10);

		var animNum:Int = FlxG.random.int(1, maxAnims);
		animation.play('note' + direction + '-' + animNum, true);
		
		var minFps:Int = 22;
		var maxFps:Int = 26;
		if(config != null)
		{
			var animID:Int = direction + ((animNum - 1) * Note.colArray.length);
			//trace('anim: ${animation.curAnim.name}, $animID');
			var offs:Array<Float> = config.offsets[FlxMath.wrap(animID, 0, config.offsets.length-1)];
			offset.x += offs[0];
			offset.y += offs[1];
			minFps = config.minFps;
			maxFps = config.maxFps;
		}

		if(animation.curAnim != null)
			animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
	}

	public static function getSplashSkin()
	{
		var skin:String = defaultNoteSplash;
		if(ClientPrefs.data.splashSkin != ClientPrefs.defaultData.splashSkin)
			skin += '-' + ClientPrefs.data.splashSkin.trim().toLowerCase().replace(' ', '_');
		return skin;
	}

	function loadAnims(skin:String, ?config:NoteSplashConfig = null, ?animName:String = null):NoteSplashConfig {
		maxAnims = 0;
		frames = Paths.getSparrowAtlas(skin);

		if(animName == null)
			animName = config != null ? config.anim : 'note splash';

		var config:NoteSplashConfig = precacheConfig(skin);
		while(true) {
			var animID:Int = maxAnims + 1;
			for (i in 0...Note.colArray.length) {
				if (!addAnimAndCheck('note$i-$animID', '$animName ${Note.colArray[i]} $animID', 24, false)) {
					//trace('maxAnims: $maxAnims');
					return config;
				}
			}
			maxAnims++;
			//trace('currently: $maxAnims');
		}
	}

	public static function precacheConfig(skin:String)
	{
		if(configs.exists(skin)) return configs.get(skin);

		var path:String = Paths.getPath('images/$skin.txt', TEXT);
		var configFile:Array<String> = CoolUtil.coolTextFile(path);
		if(configFile.length < 1) return null;
		
		var framerates:Array<String> = configFile[1].split(' ');
		var offs:Array<Array<Float>> = [];
		for (i in 2...configFile.length)
		{
			var animOffs:Array<String> = configFile[i].split(' ');
			offs.push([Std.parseFloat(animOffs[0]), Std.parseFloat(animOffs[1])]);
		}

		var config:NoteSplashConfig = {
			anim: configFile[0],
			minFps: Std.parseInt(framerates[0]),
			maxFps: Std.parseInt(framerates[1]),
			offsets: offs
		};
		//trace(config);
		configs.set(skin, config);
		return config;
	}

	function addAnimAndCheck(name:String, anim:String, ?framerate:Int = 24, ?loop:Bool = false)
	{
		animation.addByPrefix(name, anim, framerate, loop);
		return animation.getByName(name) != null;
	}

	static var aliveTime:Float = 0;
	static var buggedKillTime:Float = 0.5; //automatically kills note splashes if they break to prevent it from flooding your HUD
	override function update(elapsed:Float) {
		aliveTime += elapsed;
		if((animation.curAnim != null && animation.curAnim.finished) ||
			(animation.curAnim == null && aliveTime >= buggedKillTime)) kill();

		super.update(elapsed);
	}

	////////////////////
	// Pixel Splashes //
	////////////////////

	private static var pixelSplashShader(default, never):PixelSplashShaderRef = new PixelSplashShaderRef();

	@:noCompletion
	override function drawComplex(camera:FlxCamera):Void
	{
		if(!PlayState.isPixelStage)
		{
			super.drawComplex(camera);
			return;
		}

		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);

		if (bakedRotationAngle <= 0)
		{
			updateTrig();

			if (angle != 0)
				_matrix.rotateWithTrig(_cosAngle, _sinAngle);
		}

		getScreenPosition(_point, camera).subtractPoint(offset);
		_point.add(origin.x, origin.y);
		_matrix.translate(_point.x, _point.y);

		if (isPixelPerfectRender(camera))
		{
			_matrix.tx = Math.floor(_matrix.tx);
			_matrix.ty = Math.floor(_matrix.ty);
		}

		if(rgbShader != null)
		{
			for (i in 0...3)
			{
				pixelSplashShader.shader.r.value[i] = rgbShader.shader.r.value[i];
				pixelSplashShader.shader.g.value[i] = rgbShader.shader.g.value[i];
				pixelSplashShader.shader.b.value[i] = rgbShader.shader.b.value[i];
			}
			pixelSplashShader.shader.mult.value[0] = rgbShader.shader.mult.value[0];
			pixelSplashShader.shader.enabled.value[0] = rgbShader.shader.enabled.value[0];
		}
		camera.drawPixels(_frame, framePixels, _matrix, colorTransform, blend, antialiasing, pixelSplashShader.shader);
	}
}

class PixelSplashShaderRef {
	public var shader:PixelSplashShader = new PixelSplashShader();

	public function new()
	{
		shader.r.value = [0, 0, 0];
		shader.g.value = [0, 0, 0];
		shader.b.value = [0, 0, 0];
		shader.mult.value = [1];
		shader.enabled.value = [true];
		shader.uBlocksize.value = [PlayState.daPixelZoom, PlayState.daPixelZoom];
		trace('Pixel zoom: ${PlayState.daPixelZoom}');
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
		uniform bool enabled;
		uniform vec2 uBlocksize;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec2 blocks = openfl_TextureSize / uBlocksize;
			vec4 color = flixel_texture2D(bitmap, floor(coord * blocks) / blocks);
			if (!hasTransform) {
				return color;
			}

			if(!enabled || color.a == 0.0 || mult == 0.0) {
				return color * openfl_Alphav;
			}

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;
			
			color = mix(color, newColor, mult);
			
			if(color.a > 0.0) {
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