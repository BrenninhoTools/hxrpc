package discord.play;

import discord.util.TimerRpc;
import haxe.Timer;

typedef SessionStats = {
    var totalPlayedSeconds:Float;
    var currentSessionSeconds:Float;
    var totalSessions:Int;
    var isPaused:Bool;
}

class PlayTime {
    public static var isTracking(default, null):Bool = false;
    public static var isPaused(default, null):Bool = false;

    static var totalPlayedDuration:Float = 0;
    static var sessionCounter:Int = 0;
    static var tickTimer:Timer;
    static var onTickCallback:Float->Void;
    static var onTargetReachedCallback:Void->Void;
    static var targetDurationSeconds:Float = 0;

    public static function start(?targetSeconds:Float = 0, ?onTick:Float->Void, ?onTargetReached:Void->Void):Void {
        stop();

        isTracking = true;
        isPaused = false;
        sessionCounter++;
        targetDurationSeconds = targetSeconds;
        onTickCallback = onTick;
        onTargetReachedCallback = onTargetReached;

        TimerRpc.start();

        tickTimer = new Timer(1000);
        tickTimer.run = handleTick;
    }

    public static function pause():Void {
        if (!isTracking || isPaused) return;

        isPaused = true;
        TimerRpc.pause();

        if (tickTimer != null) {
            tickTimer.stop();
            tickTimer = null;
        }
    }

    public static function resume():Void {
        if (!isTracking || !isPaused) return;

        isPaused = false;
        TimerRpc.resume();

        tickTimer = new Timer(1000);
        tickTimer.run = handleTick;
    }

    public static function stop():Void {
        if (isTracking && !isPaused) {
            totalPlayedDuration += TimerRpc.elapsedSeconds;
        }

        if (tickTimer != null) {
            tickTimer.stop();
            tickTimer = null;
        }

        TimerRpc.stop();
        isTracking = false;
        isPaused = false;
        targetDurationSeconds = 0;
        onTickCallback = null;
        onTargetReachedCallback = null;
    }

    public static function getSessionSeconds():Float {
        if (!isTracking) return 0;
        return TimerRpc.elapsedSeconds;
    }

    public static function getTotalPlayedSeconds():Float {
        return totalPlayedDuration + getSessionSeconds();
    }

    public static function getFormattedSessionTime():String {
        return TimerRpc.formatTime(getSessionSeconds());
    }

    public static function getFormattedTotalTime():String {
        return TimerRpc.formatTime(getTotalPlayedSeconds());
    }

    public static function getStats():SessionStats {
        return {
            totalPlayedSeconds: getTotalPlayedSeconds(),
            currentSessionSeconds: getSessionSeconds(),
            totalSessions: sessionCounter,
            isPaused: isPaused
        };
    }

    public static function resetStats():Void {
        stop();
        totalPlayedDuration = 0;
        sessionCounter = 0;
    }

    static function handleTick():Void {
        var currentSession:Float = getSessionSeconds();

        if (onTickCallback != null) {
            onTickCallback(currentSession);
        }

        if (targetDurationSeconds > 0 && currentSession >= targetDurationSeconds) {
            var callback:Void->Void = onTargetReachedCallback;
            onTargetReachedCallback = null;
            if (callback != null) {
                callback();
            }
        }
    }
}
