package discord.ui;

import discord.util.TimerRpc;
import haxe.Timer;

class BreakTime {
    public static var active(default, null):Bool = false;
    public static var autoResume:Bool = true;

    static var durationSeconds:Float = 0;
    static var breakTimer:Timer;
    static var onBreakStartCallback:Void->Void;
    static var onBreakEndCallback:Void->Void;
    static var onTickCallback:Float->Void;

    public static function start(seconds:Float, ?onEnd:Void->Void, ?onTick:Float->Void):Void {
        stop();

        if (seconds <= 0) return;

        durationSeconds = seconds;
        active = true;
        onBreakEndCallback = onEnd;
        onTickCallback = onTick;

        TimerRpc.start();

        breakTimer = new Timer(1000);
        breakTimer.run = function() {
            var remaining:Float = getRemainingSeconds();

            if (onTickCallback != null) {
                onTickCallback(remaining);
            }

            if (remaining <= 0) {
                completeBreak();
            }
        };

        if (onBreakStartCallback != null) {
            onBreakStartCallback();
        }
    }

    public static function pause():Void {
        if (!active) return;
        TimerRpc.pause();
        if (breakTimer != null) {
            breakTimer.stop();
            breakTimer = null;
        }
    }

    public static function resume():Void {
        if (!active || breakTimer != null) return;
        TimerRpc.resume();

        breakTimer = new Timer(1000);
        breakTimer.run = function() {
            var remaining:Float = getRemainingSeconds();

            if (onTickCallback != null) {
                onTickCallback(remaining);
            }

            if (remaining <= 0) {
                completeBreak();
            }
        };
    }

    public static function stop():Void {
        if (breakTimer != null) {
            breakTimer.stop();
            breakTimer = null;
        }
        TimerRpc.stop();
        active = false;
        durationSeconds = 0;
        onBreakStartCallback = null;
        onBreakEndCallback = null;
        onTickCallback = null;
    }

    public static function getRemainingSeconds():Float {
        if (!active) return 0;
        var remaining:Float = durationSeconds - TimerRpc.elapsedSeconds;
        return remaining > 0 ? remaining : 0;
    }

    public static function getFormattedRemaining():String {
        return TimerRpc.formatTime(getRemainingSeconds());
    }

    public static function setOnBreakStart(callback:Void->Void):Void {
        onBreakStartCallback = callback;
    }

    static function completeBreak():Void {
        var callback:Void->Void = onBreakEndCallback;
        stop();
        if (callback != null) {
            callback();
        }
    }
}
