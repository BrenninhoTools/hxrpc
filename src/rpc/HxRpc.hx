package rpc;

import discord.Activity;
import discord.Backend;
import haxe.Timer;

typedef HxRpcConfig = {
    var ?autoReconnect:Bool;
    var ?reconnectInterval:Float;
    var ?maxReconnectAttempts:Int;
    var ?rateLimitInterval:Float;
}

class HxRpc {
    public static var connected(default, null):Bool = false;
    public static var autoReconnect:Bool = true;
    public static var reconnectInterval:Float = 5.0;
    public static var maxReconnectAttempts:Int = 10;
    public static var rateLimitInterval:Float = 1.2;

    public static var onConnected:Void->Void;
    public static var onDisconnected:Void->Void;
    public static var onError:String->Void;

    static var backend:Backend;
    static var storedClientId:String;
    static var storedWebhookUrl:String;
    static var current:Activity = {};
    static var pendingActivity:Activity;

    static var reconnectTimer:Timer;
    static var rateLimitTimer:Timer;
    static var currentReconnectAttempts:Int = 0;
    static var lastUpdateTime:Float = 0;

    public static function init(clientId:String, ?webhookUrl:String, ?config:HxRpcConfig):Bool {
        if (clientId == null || clientId == "") {
            dispatchError("Initialization failed: Client ID is missing.");
            return false;
        }

        storedClientId = clientId;
        storedWebhookUrl = webhookUrl;

        if (config != null) {
            if (config.autoReconnect != null) autoReconnect = config.autoReconnect;
            if (config.reconnectInterval != null) reconnectInterval = config.reconnectInterval;
            if (config.maxReconnectAttempts != null) maxReconnectAttempts = config.maxReconnectAttempts;
            if (config.rateLimitInterval != null) rateLimitInterval = config.rateLimitInterval;
        }

        #if (windows || mac || linux)
        backend = new discord.native.DiscordIPC();
        #elseif (android || ios)
        backend = new discord.mobile.DiscordWebhook(webhookUrl);
        #else
        backend = null;
        #end

        if (backend == null) {
            setConnected(false);
            dispatchError("No RPC backend available for this target platform.");
            return false;
        }

        currentReconnectAttempts = 0;
        return connectInternal();
    }

    public static function setActivity(activity:Activity):Bool {
        pendingActivity = activity;

        var now:Float = Date.now().getTime() / 1000;
        if (now - lastUpdateTime < rateLimitInterval) {
            scheduleRateLimitedUpdate();
            return false;
        }

        return dispatchActivity(activity);
    }

    public static function setDetails(details:String, ?state:String):Bool {
        var activity:Activity = cloneActivity(current);
        activity.details = details;
        if (state != null) activity.state = state;
        return setActivity(activity);
    }

    public static function setState(state:String):Bool {
        var activity:Activity = cloneActivity(current);
        activity.state = state;
        return setActivity(activity);
    }

    public static function setTimestamps(start:Float, ?end:Float):Bool {
        var activity:Activity = cloneActivity(current);
        activity.startTimestamp = start;
        activity.endTimestamp = end;
        return setActivity(activity);
    }

    public static function setImages(largeImageKey:String, ?largeImageText:String, ?smallImageKey:String, ?smallImageText:String):Bool {
        var activity:Activity = cloneActivity(current);
        activity.largeImageKey = largeImageKey;
        activity.largeImageText = largeImageText;
        activity.smallImageKey = smallImageKey;
        activity.smallImageText = smallImageText;
        return setActivity(activity);
    }

    public static function setParty(partyId:String, size:Int, max:Int):Bool {
        var activity:Activity = cloneActivity(current);
        activity.partyId = partyId;
        activity.partySize = size;
        activity.partyMax = max;
        return setActivity(activity);
    }

    public static function setSecrets(match:String, ?join:String, ?spectate:String):Bool {
        var activity:Activity = cloneActivity(current);
        activity.matchSecret = match;
        activity.joinSecret = join;
        activity.spectateSecret = spectate;
        return setActivity(activity);
    }

    public static function setButtons(buttons:Array<{label:String, url:String}>):Bool {
        var activity:Activity = cloneActivity(current);
        activity.buttons = buttons;
        return setActivity(activity);
    }

    public static function clearActivity():Bool {
        stopRateLimitTimer();
        pendingActivity = null;
        current = {};

        if (!checkConnection()) return false;
        var ok:Bool = backend.clearActivity();
        if (!ok) dispatchError("Failed to clear activity.");
        return ok;
    }

    public static function reconnect():Bool {
        if (storedClientId == null) {
            dispatchError("Cannot reconnect before init() was called.");
            return false;
        }
        stopReconnectTimer();
        currentReconnectAttempts = 0;
        return connectInternal();
    }

    public static function shutdown():Void {
        stopReconnectTimer();
        stopRateLimitTimer();

        if (backend != null) {
            backend.clearActivity();
            backend.disconnect();
        }

        setConnected(false);
        backend = null;
        current = {};
        pendingActivity = null;
        storedClientId = null;
        storedWebhookUrl = null;
        onConnected = null;
        onDisconnected = null;
        onError = null;
    }

    static function dispatchActivity(activity:Activity):Bool {
        if (!checkConnection()) return false;

        current = activity;
        pendingActivity = null;
        lastUpdateTime = Date.now().getTime() / 1000;

        var ok:Bool = backend.setActivity(activity);
        if (!ok) dispatchError("Failed to set activity payload.");
        return ok;
    }

    static function scheduleRateLimitedUpdate():Void {
        if (rateLimitTimer != null) return;

        var delay:Int = Std.int(rateLimitInterval * 1000);
        rateLimitTimer = new Timer(delay);
        rateLimitTimer.run = function() {
            stopRateLimitTimer();
            if (pendingActivity != null) {
                dispatchActivity(pendingActivity);
            }
        };
    }

    static function connectInternal():Bool {
        if (backend == null) return false;

        var status:Bool = backend.connect(storedClientId);
        setConnected(status);

        if (connected) {
            stopReconnectTimer();
            currentReconnectAttempts = 0;
            if (pendingActivity != null) {
                dispatchActivity(pendingActivity);
            } else if (current != null) {
                dispatchActivity(current);
            }
        } else {
            dispatchError("Failed to connect to Discord.");
            if (autoReconnect) {
                scheduleReconnect();
            }
        }

        return connected;
    }

    static function checkConnection():Bool {
        if (!connected && autoReconnect && storedClientId != null) {
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
        var delay:Int = Std.int(reconnectInterval * 1000 * Math.min(currentReconnectAttempts, 4));

        reconnectTimer = new Timer(delay);
        reconnectTimer.run = function() {
            stopReconnectTimer();
            if (!connected && storedClientId != null) {
                connectInternal();
            }
        };
    }

    static function setConnected(value:Bool):Void {
        if (connected != value) {
            connected = value;
            if (connected) {
                if (onConnected != null) onConnected();
            } else {
                if (onDisconnected != null) onDisconnected();
            }
        }
    }

    static function dispatchError(message:String):Void {
        if (onError != null) onError(message);
    }

    static function cloneActivity(src:Activity):Activity {
        if (src == null) return {};
        return {
            details: src.details,
            state: src.state,
            startTimestamp: src.startTimestamp,
            endTimestamp: src.endTimestamp,
            largeImageKey: src.largeImageKey,
            largeImageText: src.largeImageText,
            smallImageKey: src.smallImageKey,
            smallImageText: src.smallImageText,
            partyId: src.partyId,
            partySize: src.partySize,
            partyMax: src.partyMax,
            matchSecret: src.matchSecret,
            joinSecret: src.joinSecret,
            spectateSecret: src.spectateSecret,
            instance: src.instance,
            buttons: src.buttons
        };
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
