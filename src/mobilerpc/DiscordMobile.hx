package mobilerpc;

import discord.Activity;
import discord.mobile.DiscordWebhook;
import haxe.Timer;

typedef PresenceData = {
    var ?details:String;
    var ?state:String;
    var ?largeImageKey:String;
    var ?largeImageText:String;
    var ?smallImageKey:String;
    var ?smallImageText:String;
    var ?startTimestamp:Float;
    var ?endTimestamp:Float;
    var ?partyId:String;
    var ?partySize:Int;
    var ?partyMax:Int;
    var ?matchSecret:String;
    var ?joinSecret:String;
    var ?spectateSecret:String;
    var ?instance:Bool;
}

class DiscordMobile {
    public static var connected(default, null):Bool = false;
    public static var autoReconnect:Bool = true;
    public static var reconnectInterval:Float = 5.0;

    static var backend:DiscordWebhook;
    static var currentWebhookUrl:String;
    static var sessionStart:Float;
    static var currentActivity:Activity;
    static var reconnectTimer:Timer;

    public static function init(webhookUrl:String):Bool {
        if (webhookUrl == null || webhookUrl == "") return false;
        
        currentWebhookUrl = webhookUrl;
        sessionStart = Date.now().getTime() / 1000;
        
        return connectInternal();
    }

    public static function update(details:String, ?state:String, ?largeImageKey:String, ?largeImageText:String):Bool {
        return updateCustom({
            details: details,
            state: state,
            largeImageKey: largeImageKey,
            largeImageText: largeImageText,
            startTimestamp: sessionStart
        });
    }

    public static function updateCustom(data:PresenceData):Bool {
        if (!checkConnection()) return false;

        var activity:Activity = {
            details: data.details,
            state: data.state,
            timestamps: (data.startTimestamp != null || data.endTimestamp != null) ? {
                start: data.startTimestamp,
                end: data.endTimestamp
            } : null,
            assets: (data.largeImageKey != null || data.smallImageKey != null) ? {
                largeImage: data.largeImageKey,
                largeText: data.largeImageText,
                smallImage: data.smallImageKey,
                smallText: data.smallImageText
            } : null,
            party: (data.partyId != null) ? {
                id: data.partyId,
                size: (data.partySize != null && data.partyMax != null) ? [data.partySize, data.partyMax] : null
            } : null,
            secrets: (data.matchSecret != null || data.joinSecret != null || data.spectateSecret != null) ? {
                match: data.matchSecret,
                join: data.joinSecret,
                spectate: data.spectateSecret
            } : null,
            instance: data.instance
        };

        currentActivity = activity;
        return backend.setActivity(activity);
    }

    public static function updateActivity(activity:Activity):Bool {
        if (!checkConnection()) return false;
        currentActivity = activity;
        return backend.setActivity(activity);
    }

    public static function clear():Bool {
        if (!checkConnection()) return false;
        currentActivity = null;
        return backend.clearActivity();
    }

    public static function resetSession():Void {
        sessionStart = Date.now().getTime() / 1000;
        if (currentActivity != null && currentActivity.timestamps != null) {
            currentActivity.timestamps.start = sessionStart;
            if (connected) backend.setActivity(currentActivity);
        }
    }

    public static function shutdown():Void {
        stopReconnectTimer();
        if (backend != null) {
            backend.clearActivity();
            backend.disconnect();
        }
        connected = false;
        backend = null;
        currentActivity = null;
        currentWebhookUrl = null;
    }

    static function connectInternal():Bool {
        if (backend == null) backend = new DiscordWebhook(currentWebhookUrl);
        connected = backend.connect(currentWebhookUrl);

        if (connected) {
            stopReconnectTimer();
            if (currentActivity != null) backend.setActivity(currentActivity);
        } else if (autoReconnect) {
            scheduleReconnect();
        }

        return connected;
    }

    static function checkConnection():Bool {
        if (!connected && autoReconnect && currentWebhookUrl != null) {
            connectInternal();
        }
        return connected && backend != null;
    }

    static function scheduleReconnect():Void {
        if (reconnectTimer != null) return;
        reconnectTimer = new Timer(Std.int(reconnectInterval * 1000));
        reconnectTimer.run = function() {
            if (!connected && currentWebhookUrl != null) {
                connectInternal();
            } else {
                stopReconnectTimer();
            }
        };
    }

    static function stopReconnectTimer():Void {
        if (reconnectTimer != null) {
            reconnectTimer.stop();
            reconnectTimer = null;
        }
    }
}
