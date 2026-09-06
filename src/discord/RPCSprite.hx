package discord;

#if flixel
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import rpc.HxRpc;

class RPCSprite extends FlxSprite {
    public var connectedColor:FlxColor = 0xFF57F287;
    public var disconnectedColor:FlxColor = 0xFFED4245;
    public var connectingColor:FlxColor = 0xFFFEE75C;
    public var pulseColor:FlxColor = 0xFFFFFFFF;

    public var enablePulse:Bool = true;
    public var pulseSpeed:Float = 4.0;
    public var pulseIntensity:Float = 0.3;

    public var onStatusChanged:Bool->Void;

    var diameter:Int = 16;
    var lastConnected:Bool = false;
    var pulseTimer:Float = 0;
    var targetColor:FlxColor;

    public function new(x:Float = 0, y:Float = 0, size:Int = 16) {
        super(x, y);
        this.diameter = size;
        drawCircleGraphic();

        lastConnected = HxRpc.connected;
        targetColor = lastConnected ? connectedColor : disconnectedColor;
        color = targetColor;
        
        setupCallbacks();
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        checkStatusChange();

        if (enablePulse) {
            updatePulse(elapsed);
        }
    }

    public function redraw(newSize:Int):Void {
        this.diameter = newSize;
        drawCircleGraphic();
        refreshStatus();
    }

    public function refreshStatus():Void {
        lastConnected = HxRpc.connected;
        targetColor = lastConnected ? connectedColor : disconnectedColor;
        color = targetColor;
        alpha = 1.0;
    }

    override public function destroy():Void {
        onStatusChanged = null;
        super.destroy();
    }

    function drawCircleGraphic():Void {
        makeGraphic(diameter, diameter, FlxColor.TRANSPARENT, true);

        var radius:Float = diameter / 2;
        var drawWidth:Int = frameWidth;
        var drawHeight:Int = frameHeight;

        for (px in 0...drawWidth) {
            for (py in 0...drawHeight) {
                var dx:Float = px - radius + 0.5;
                var dy:Float = py - radius + 0.5;
                var distSq:Float = dx * dx + dy * dy;

                if (distSq <= radius * radius) {
                    var alphaVal:Float = 1.0;
                    var edgeDist:Float = radius - Math.sqrt(distSq);
                    if (edgeDist < 1.0) {
                        alphaVal = FlxMath.bound(edgeDist, 0, 1);
                    }
                    pixels.setPixel32(px, py, FlxColor.fromRGBFloat(1, 1, 1, alphaVal));
                }
            }
        }
        dirty = true;
    }

    function checkStatusChange():Void {
        var currentConnected:Bool = HxRpc.connected;
        if (currentConnected != lastConnected) {
            lastConnected = currentConnected;
            targetColor = lastConnected ? connectedColor : disconnectedColor;
            color = targetColor;

            if (onStatusChanged != null) {
                onStatusChanged(lastConnected);
            }
        }
    }

    function updatePulse(elapsed:Float):Void {
        pulseTimer += elapsed * pulseSpeed;
        var sineWave:Float = (Math.sin(pulseTimer) + 1.0) * 0.5;

        if (lastConnected) {
            alpha = 1.0 - (sineWave * pulseIntensity);
        } else {
            alpha = 0.6 + (sineWave * pulseIntensity * 0.4);
        }
    }

    function setupCallbacks():Void {
        var prevConnect = HxRpc.onConnected;
        HxRpc.onConnected = function() {
            if (prevConnect != null) prevConnect();
            refreshStatus();
        };

        var prevDisconnect = HxRpc.onDisconnected;
        HxRpc.onDisconnected = function() {
            if (prevDisconnect != null) prevDisconnect();
            refreshStatus();
        };
    }
}
#end
