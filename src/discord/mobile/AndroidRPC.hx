package discord.mobile;

import discord.Activity;
import discord.util.TimerRpc;
import haxe.Timer;

#if android
import extension.android.AndroidNative;
#end

typedef MobilePresenceData = {
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
    var ?useTimer:Bool;
}

class AndroidRPC {
    public static var connected(default, null):Bool = false;
    public static var autoReconnect:Bool = true;
    public static var reconnectInterval:Float = 5.0;
    public static var pauseOnBackground:Bool = true;
    public static var isLowBatteryMode(default, null):Bool = false;

    static var backend:DiscordWebhook;
    static var currentWebhookUrl:String;
    static var lastPresence:MobilePresenceData;
    static var reconnectTimer:Timer;
    static var backgroundTimer:Timer;
    static var isAppInBackground:Bool = false;

    public static function init(webhookUrl:String, ?enableLifecycleHooks:Bool = true):Bool {
        if (webhookUrl == null || webhookUrl == "") return false;

        currentWebhookUrl = webhookUrl;
        TimerRpc.start();

        if (enableLifecycleHooks) {
            setupLifecycleHooks();
        }

        return connectInternal();
    }

    public static function update(details:String, ?state:String, ?largeImageKey:String, ?largeImageText:String):Bool {
        return updatePresence({
            details: details,
            state: state,
            largeImageKey: largeImageKey,
            largeImageText: largeImageText,
            useTimer: true
        });
    }

    public static function updatePresence(data:MobilePresenceData):Bool {
        if (isLowBatteryMode || !checkConnection()) return false;

        lastPresence = data;

        var startTime:Null<Float> = null;
        if (data.useTimer != false) {
            startTime = data.startTimestamp != null ? data.startTimestamp : TimerRpc.getStartTimestamp();
        } else {
            startTime = data.startTimestamp;
        }

        var activity:Activity = {
            details: data.details,
            state: data.state,
            timestamps: (startTime != null || data.endTimestamp != null) ? {
                start: startTime,
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

        return backend.setActivity(activity);
    }

    public static function updateActivity(activity:Activity):Bool {
        if (isLowBatteryMode || !checkConnection()) return false;

        if (activity.timestamps == null && TimerRpc.getStartTimestamp() > 0) {
            activity.timestamps = {
                start: TimerRpc.getStartTimestamp()
            };
        }

        return backend.setActivity(activity);
    }

    public static function clear():Bool {
        if (!checkConnection()) return false;
        lastPresence = null;
        return backend.clearActivity();
    }

    public static function onPause():Void {
        isAppInBackground = true;
        
        if (pauseOnBackground) {
            TimerRpc.pause();
            if (connected && backend != null) {
                backend.clearActivity();
            }
        }
    }

    public static function onResume():Void {
        isAppInBackground = false;

        if (pauseOnBackground) {
            TimerRpc.resume();
        }

        if (lastPresence != null) {
            updatePresence(lastPresence);
        }
    }

    public static function setLowBatteryMode(enabled:Bool):Void {
        isLowBatteryMode = enabled;

        if (isLowBatteryMode) {
            stopReconnectTimer();
            if (connected && backend != null) {
                backend.clearActivity();
            }
        } else {
            if (lastPresence != null) {
                updatePresence(lastPresence);
            }
        }
    }

    public static function updateDeviceStatus(batteryLevel:Int, isCharging:Bool, ?networkType:String):Bool {
        if (lastPresence == null) return false;

        var batteryIcon:String = isCharging ? "charging_icon" : "battery_icon";
        var statusText:String = batteryLevel + "%" + (isCharging ? " (Charging)" : "");
        
        if (networkType != null) {
            statusText += " | " + networkType;
        }

        lastPresence.smallImageKey = batteryIcon;
        lastPresence.smallImageText = statusText;

        return updatePresence(lastPresence);
    }

    public static function resetSession():Void {
        TimerRpc.start();
        if (lastPresence != null) {
            lastPresence.startTimestamp = TimerRpc.getStartTimestamp();
            updatePresence(lastPresence);
        }
    }

    public static function shutdown():Void {
        stopReconnectTimer();
        stopBackgroundTimer();
        TimerRpc.stop();

        if (backend != null) {
            backend.clearActivity();
            backend.disconnect();
        }

        connected = false;
        backend = null;
        lastPresence = null;
        currentWebhookUrl = null;
        isAppInBackground = false;
    }

    static function setupLifecycleHooks():Void {
        #if limelight
        lime.app.Application.current.onExit.add(function(_) {
            shutdown();
        });
        #end
    }

    static function connectInternal():Bool {
        if (backend == null) backend = new DiscordWebhook(currentWebhookUrl);
        connected = backend.connect(currentWebhookUrl);

        if (connected) {
            stopReconnectTimer();
            if (lastPresence != null && !isLowBatteryMode) {
                updatePresence(lastPresence);
            }
        } else if (autoReconnect && !isLowBatteryMode) {
            scheduleReconnect();
        }

        return connected;
    }

    static function checkConnection():Bool {
        if (!connected && autoReconnect && currentWebhookUrl != null && !isLowBatteryMode) {
            connectInternal();
        }
        return connected && backend != null;
    }

    static function scheduleReconnect():Void {
        if (reconnectTimer != null) return;
        reconnectTimer = new Timer(Std.int(reconnectInterval * 1000));
        reconnectTimer.run = function() {
            if (!connected && currentWebhookUrl != null && !isLowBatteryMode) {
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

    static function stopBackgroundTimer():Void {
        if (backgroundTimer != null) {
            backgroundTimer.stop();
            backgroundTimer = null;
        }
    }
}
