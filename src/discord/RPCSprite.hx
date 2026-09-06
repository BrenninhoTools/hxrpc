package discord;

#if flixel
import flixel.FlxSprite;
import flixel.util.FlxColor;
import rpc.HxRpc;

class RPCSprite extends FlxSprite {
    public var connectedColor:FlxColor = FlxColor.LIME;
    public var disconnectedColor:FlxColor = FlxColor.RED;
    public var size:Int = 16;

    var lastConnected:Bool;

    public function new(x:Float = 0, y:Float = 0, ?size:Int) {
        super(x, y);
        if (size != null) this.size = size;
        makeGraphic(this.size, this.size, disconnectedColor);
        lastConnected = HxRpc.connected;
        refresh();
    }

    override function update(elapsed:Float):Void {
        super.update(elapsed);
        if (HxRpc.connected != lastConnected) {
            lastConnected = HxRpc.connected;
            refresh();
        }
    }

    function refresh():Void {
        color = lastConnected ? connectedColor : disconnectedColor;
    }
}
#end
