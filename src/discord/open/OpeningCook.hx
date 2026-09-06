package discord.open;

import discord.mobile.AndroidRPC;
import discord.play.PlayTime;
import discord.ui.BreakTime;
import discord.util.TimerRpc;

typedef OpeningStateOptions = {
    var title:String;
    var ?subtitle:String;
    var ?largeImageKey:String;
    var ?largeImageText:String;
    var ?smallImageKey:String;
    var ?smallImageText:String;
    var ?trackPlayTime:Bool;
    var ?targetDuration:Float;
    var ?onTargetReached:Void->Void;
}

class OpeningCook {
    public static var isCooking(default, null):Bool = false;
    public static var currentTitle(default, null):String = "";
    public static var currentSubtitle(default, null):String = "";

    static var defaultWebhookUrl:String;
    static var lastOptions:OpeningStateOptions;

    public static function setup(webhookUrl:String, ?autoConnect:Bool = true):Bool {
        defaultWebhookUrl = webhookUrl;
        
        if (autoConnect && webhookUrl != null && webhookUrl != "") {
            return AndroidRPC.init(webhookUrl);
        }
        return false;
    }

    public static function cookState(options:OpeningStateOptions):Bool {
        if (options == null || options.title == null) return false;

        lastOptions = options;
        currentTitle = options.title;
        currentSubtitle = options.subtitle != null ? options.subtitle : "";
        isCooking = true;

        if (options.trackPlayTime != false) {
            PlayTime.start(
                options.targetDuration != null ? options.targetDuration : 0,
                null,
                options.onTargetReached
            );
        }

        return syncToPresence();
    }

    public static function cookBreak(breakSeconds:Float, ?breakTitle:String = "Taking a Break", ?onBreakEnd:Void->Void):Void {
        if (breakSeconds <= 0) return;

        currentTitle = breakTitle;
        currentSubtitle = "Back in " + TimerRpc.formatTime(breakSeconds);

        BreakTime.start(breakSeconds, function() {
            if (onBreakEnd != null) {
                onBreakEnd();
            }
            if (lastOptions != null) {
                cookState(lastOptions);
            } else {
                resumeState();
            }
        }, function(remaining:Float) {
            currentSubtitle = "Back in " + TimerRpc.formatTime(remaining);
            syncToPresence();
        });

        syncToPresence();
    }

    public static function pauseState():Void {
        if (!isCooking) return;
        PlayTime.pause();
        BreakTime.pause();
        AndroidRPC.pauseSession();
    }

    public static function resumeState():Void {
        if (!isCooking) return;
        AndroidRPC.resumeSession();
        PlayTime.resume();
        BreakTime.resume();
        syncToPresence();
    }

    public static function stopCooking():Void {
        BreakTime.stop();
        PlayTime.stop();
        AndroidRPC.clear();

        isCooking = false;
        currentTitle = "";
        currentSubtitle = "";
        lastOptions = null;
    }

    public static function shutdown():Void {
        stopCooking();
        AndroidRPC.shutdown();
        defaultWebhookUrl = null;
    }

    static function syncToPresence():Bool {
        if (!isCooking) return false;

        var largeImg:String = lastOptions != null ? lastOptions.largeImageKey : null;
        var largeTxt:String = lastOptions != null ? lastOptions.largeImageText : null;
        var smallImg:String = lastOptions != null ? lastOptions.smallImageKey : null;
        var smallTxt:String = lastOptions != null ? lastOptions.smallImageText : null;

        return AndroidRPC.updatePresence({
            details: currentTitle,
            state: currentSubtitle,
            largeImageKey: largeImg,
            largeImageText: largeTxt,
            smallImageKey: smallImg,
            smallImageText: smallTxt,
            useTimer: true
        });
    }
}
