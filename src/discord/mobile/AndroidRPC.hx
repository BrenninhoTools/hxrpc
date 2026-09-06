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
    public static var maxReconnectAttempts:Int = 10;
    public static var pauseOnBackground:Bool = true;
    public static var isLowBatteryMode(default, null):Bool = false;
    public static var rateLimitInterval:Float = 1.2;

    public static var onError:String->Void;
    public static var onStatusChange:Bool->Void;

    static var backend:DiscordWebhook;
    static var currentWebhookUrl:String;
    static var lastPresence:MobilePresenceData;
    static var pendingPresence:MobilePresenceData;

    static var reconnectTimer:Timer;
    static var rateLimitTimer:Timer;
    static var currentReconnectAttempts:Int = 0;
    static var lastUpdateTime:Float = 0;

    static var isAppInBackground:Bool = false;
    static var isThrottled:Bool = false;

    public static function init(webhookUrl:String, ?enableLifecycleHooks:Bool = true):Bool {
        if (webhookUrl == null || webhookUrl == "") {
            dispatchError("Initialization failed: Webhook URL is empty or null.");
            return false;
        }

        currentWebhookUrl = webhookUrl;
        currentReconnectAttempts = 0;
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
        if (isLowBatteryMode || isAppInBackground) return false;
        
        pendingPresence = data;

        var now:Float = Date.now().getTime() / 1000;
        if (now - lastUpdateTime < rateLimitInterval) {
            scheduleRateLimitedUpdate();
            return false;
        }

        return dispatchPresence(data);
    }

    public static function updateActivity(activity:Activity):Bool {
        if (isLowBatteryMode || isAppInBackground || !checkConnection()) return false;

        if (activity.timestamps == null && TimerRpc.getStartTimestamp() > 0) {
            activity.timestamps = {
                start: TimerRpc.getStartTimestamp()
            };
        }

        lastUpdateTime = Date.now().getTime() / 1000;
        return backend.setActivity(activity);
    }

    public static function clear():Bool {
        stopRateLimitTimer();
        pendingPresence = null;
        lastPresence = null;

        if (!checkConnection()) return false;
        return backend.clearActivity();
    }

    public static function onPause():Void {
        isAppInBackground = true;

        if (pauseOnBackground) {
            TimerRpc.pause();
            stopRateLimitTimer();
            stopReconnectTimer();

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

        if (!connected && currentWebhookUrl != null) {
            currentReconnectAttempts = 0;
            connectInternal();
        } else if (pendingPresence != null) {
            updatePresence(pendingPresence);
        } else if (lastPresence != null) {
            updatePresence(lastPresence);
        }
    }

    public static function setLowBatteryMode(enabled:Bool):Void {
        if (isLowBatteryMode == enabled) return;
        isLowBatteryMode = enabled;

        if (isLowBatteryMode) {
            stopReconnectTimer();
            stopRateLimitTimer();
            if (connected && backend != null) {
                backend.clearActivity();
            }
        } else {
            currentReconnectAttempts = 0;
            if (pendingPresence != null) {
                updatePresence(pendingPresence);
            } else if (lastPresence != null) {
                updatePresence(lastPresence);
            }
        }
    }

    public static function updateDeviceStatus(batteryLevel:Int, isCharging:Bool, ?networkType:String):Bool {
        var targetPresence:MobilePresenceData = pendingPresence != null ? pendingPresence : lastPresence;
        if (targetPresence == null) return false;

        var batteryIcon:String = isCharging ? "charging_icon" : "battery_icon";
        var statusText:String = batteryLevel + "%" + (isCharging ? " (Charging)" : "");

        if (networkType != null) {
            statusText += " | " + networkType;
        }

        targetPresence.smallImageKey = batteryIcon;
        targetPresence.smallImageText = statusText;

        return updatePresence(targetPresence);
    }

    public static function resetSession():Void {
        TimerRpc.start();
        var targetPresence:MobilePresenceData = pendingPresence != null ? pendingPresence : lastPresence;
        if (targetPresence != null) {
            targetPresence.startTimestamp = TimerRpc.getStartTimestamp();
            updatePresence(targetPresence);
        }
    }

    public static function forceReconnect():Bool {
        stopReconnectTimer();
        currentReconnectAttempts = 0;
        return connectInternal();
    }

    public static function shutdown():Void {
        stopReconnectTimer();
        stopRateLimitTimer();
        TimerRpc.stop();

        if (backend != null) {
            backend.clearActivity();
            backend.disconnect();
        }

        setConnected(false);
        backend = null;
        lastPresence = null;
        pendingPresence = null;
        currentWebhookUrl = null;
        isAppInBackground = false;
        onError = null;
        onStatusChange = null;
    }

    static function dispatchPresence(data:MobilePresenceData):Bool {
        if (!checkConnection()) return false;

        lastPresence = data;
        pendingPresence = null;
        lastUpdateTime = Date.now().getTime() / 1000;

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

        var success:Bool = backend.setActivity(activity);
        if (!success) {
            dispatchError("Failed to update activity payload.");
        }
        return success;
    }

    static function scheduleRateLimitedUpdate():Void {
        if (rateLimitTimer != null) return;

        var delay:Int = Std.int(rateLimitInterval * 1000);
        rateLimitTimer = new Timer(delay);
        rateLimitTimer.run = function() {
            stopRateLimitTimer();
            if (pendingPresence != null && !isLowBatteryMode && !isAppInBackground) {
                dispatchPresence(pendingPresence);
            }
        };
    }

    static function connectInternal():Bool {
        if (backend == null) backend = new DiscordWebhook(currentWebhookUrl);

        var status:Bool = backend.connect(currentWebhookUrl);
        setConnected(status);

        if (connected) {
            stopReconnectTimer();
            currentReconnectAttempts = 0;
            if (pendingPresence != null) {
                dispatchPresence(pendingPresence);
            } else if (lastPresence != null) {
                dispatchPresence(lastPresence);
            }
        } else {
            dispatchError("Connection to RPC backend failed.");
            if (autoReconnect && !isLowBatteryMode && !isAppInBackground) {
                scheduleReconnect();
            }
        }

        return connected;
    }

    static function checkConnection():Bool {
        if (!connected && autoReconnect && currentWebhookUrl != null && !isLowBatteryMode && !isAppInBackground) {
            connectInternal();
        }
        return connected && backend != null;
    }

    static function scheduleReconnect():Void {
        if (reconnectTimer != null) return;
        if (maxReconnectAttempts > 0 && currentReconnectAttempts >= maxReconnectAttempts) {
            dispatchError("Max reconnection attempts reached.");
            return;
        }

        currentReconnectAttempts++;

        var delay:Int = Std.int(reconnectInterval * 1000 * Math.min(currentReconnectAttempts, 5));
        reconnectTimer = new Timer(delay);
        reconnectTimer.run = function() {
            stopReconnectTimer();
            if (!connected && currentWebhookUrl != null && !isLowBatteryMode && !isAppInBackground) {
                connectInternal();
            }
        };
    }

    static function setConnected(value:Bool):Void {
        if (connected != value) {
            connected = value;
            if (onStatusChange != null) {
                onStatusChange(connected);
            }
        }
    }

    static function dispatchError(message:String):Void {
        if (onError != null) {
            onError(message);
        }
    }

    static function setupLifecycleHooks():Void {
        #if limelight
        lime.app.Application.current.onExit.add(function(_) {
            shutdown();
        });
        #end
    }

    static function stopReconnectTimer():Void {
        if (reconnectTimer != null) {
            reconnectTimer.stop();
            reconnectTimer = null;
        }
    }

    static function stopRateLimitTimer():Void {
        if (rateLimitTimer != null) {
            rateLimitTimer.stop();
            rateLimitTimer = null;
        }
    }
}
