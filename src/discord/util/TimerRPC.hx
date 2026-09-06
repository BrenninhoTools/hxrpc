package discord.util;

import haxe.Timer;

class TimerRpc {
    public static var elapsedSeconds(get, never):Float;
    public static var elapsedMillis(get, never):Float;

    static var startTime:Float = 0;
    static var pausedTime:Float = 0;
    static var totalPausedDuration:Float = 0;
    static var isRunning:Bool = false;

    public static function start(?customStartTimestamp:Float):Void {
        if (customStartTimestamp != null) {
            startTime = customStartTimestamp;
        } else {
            startTime = Date.now().getTime() / 1000;
        }
        pausedTime = 0;
        totalPausedDuration = 0;
        isRunning = true;
    }

    public static function pause():Void {
        if (!isRunning || pausedTime > 0) return;
        pausedTime = Date.now().getTime() / 1000;
    }

    public static function resume():Void {
        if (!isRunning || pausedTime == 0) return;
        var now:Float = Date.now().getTime() / 1000;
        totalPausedDuration += (now - pausedTime);
        pausedTime = 0;
    }

    public static function stop():Void {
        startTime = 0;
        pausedTime = 0;
        totalPausedDuration = 0;
        isRunning = false;
    }

    public static function getStartTimestamp():Float {
        return startTime;
    }

    public static function getEndTimestamp(durationSeconds:Float):Float {
        if (startTime == 0) return 0;
        return startTime + durationSeconds + totalPausedDuration;
    }

    public static function formatTime(seconds:Float):String {
        if (Math.isNaN(seconds) || seconds < 0) seconds = 0;

        var totalSec:Int = Std.int(seconds);
        var hrs:Int = Std.int(totalSec / 3600);
        var mins:Int = Std.int((totalSec % 3600) / 60);
        var secs:Int = totalSec % 60;

        var minsStr:String = (mins < 10 ? "0" : "") + mins;
        var secsStr:String = (secs < 10 ? "0" : "") + secs;

        if (hrs > 0) {
            var hrsStr:String = (hrs < 10 ? "0" : "") + hrs;
            return hrsStr + ":" + minsStr + ":" + secsStr;
        }

        return minsStr + ":" + secsStr;
    }

    static function get_elapsedSeconds():Float {
        if (!isRunning || startTime == 0) return 0;

        var currentTime:Float = (pausedTime > 0) ? pausedTime : (Date.now().getTime() / 1000);
        return currentTime - startTime - totalPausedDuration;
    }

    static function get_elapsedMillis():Float {
        return elapsedSeconds * 1000;
    }
}
