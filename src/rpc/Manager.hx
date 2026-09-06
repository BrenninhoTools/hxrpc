package rpc;

import discord.Activity;
import haxe.Timer;

typedef PresenceOptions = {
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

class Manager {
    public static var connected(get, never):Bool;
    public static var initialized(default, null):Bool = false;
    
    public static var autoReconnect:Bool = true;
    public static var reconnectInterval:Float = 5.0;

    static var clientId:String;
    static var webhookUrl:String;
    static var sessionStart:Float = 0;
    static var lastActivity:Activity;
    static var reconnectTimer:Timer;

    public static function configure(clientId:String, ?webhookUrl:String):Void {
        if (clientId == null || clientId == "") return;
        
        Manager.clientId = clientId;
        Manager.webhookUrl = webhookUrl;
        initialized = true;
    }

    public static function start():Bool {
        if (!initialized) return false;
        
        if (sessionStart == 0) {
            sessionStart = Date.now().getTime() / 1000;
        }

        return connectInternal();
    }

    public static function update(details:String, ?state:String, ?largeImageKey:String, ?largeImageText:String):Bool {
        return updateWithOptions({
            details: details,
            state: state,
            largeImageKey: largeImageKey,
            largeImageText: largeImageText,
            startTimestamp: sessionStart
        });
    }

    public static function updateWithOptions(options:PresenceOptions):Bool {
        if (!checkConnection()) return false;

        var activity:Activity = {
            details: options.details,
            state: options.state,
            startTimestamp: options.startTimestamp != null ? options.startTimestamp : sessionStart,
            endTimestamp: options.endTimestamp,
            largeImageKey: options.largeImageKey,
            largeImageText: options.largeImageText,
            smallImageKey: options.smallImageKey,
            smallImageText: options.smallImageText,
            partyId: options.partyId,
            partySize: options.partySize,
            partyMax: options.partyMax,
            matchSecret: options.matchSecret,
            joinSecret: options.joinSecret,
            spectateSecret: options.spectateSecret,
            instance: options.instance
        };

        lastActivity = activity;
        return HxRpc.setActivity(activity);
    }

    public static function updateActivity(activity:Activity):Bool {
        if (!checkConnection()) return false;

        if (activity.startTimestamp == null && sessionStart > 0) {
            activity.startTimestamp = sessionStart;
        }

        lastActivity = activity;
        return HxRpc.setActivity(activity);
    }

    public static function clear():Bool {
        if (!checkConnection()) return false;
        lastActivity = null;
        return HxRpc.clearActivity();
    }

    public static function resetSession():Void {
        sessionStart = Date.now().getTime() / 1000;
        if (lastActivity != null) {
            lastActivity.startTimestamp = sessionStart;
            if (get_connected()) {
                HxRpc.setActivity(lastActivity);
            }
        }
    }

    public static function stop():Void {
        stopReconnectTimer();
        if (get_connected()) {
            HxRpc.clearActivity();
            HxRpc.shutdown();
        }
        sessionStart = 0;
        lastActivity = null;
    }

    static function connectInternal():Bool {
        var success:Bool = HxRpc.init(clientId, webhookUrl);

        if (success) {
            stopReconnectTimer();
            if (lastActivity != null) {
                HxRpc.setActivity(lastActivity);
            }
        } else if (autoReconnect) {
            scheduleReconnect();
        }

        return success;
    }

    static function checkConnection():Bool {
        if (!get_connected() && autoReconnect && initialized) {
            connectInternal();
        }
        return get_connected();
    }

    static function scheduleReconnect():Void {
        if (reconnectTimer != null) return;
        reconnectTimer = new Timer(Std.int(reconnectInterval * 1000));
        reconnectTimer.run = function() {
            if (!get_connected() && initialized) {
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

    static function get_connected():Bool {
        return HxRpc.connected;
    }
}
