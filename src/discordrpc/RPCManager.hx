package discordrpc;

import discord.Activity;
import rpc.HxRpc;

class RPCManager {
    public static var connected(get, never):Bool;

    static var clientId:String;
    static var webhookUrl:String;
    static var sessionStart:Float;
    static var configured:Bool = false;

    public static function configure(clientId:String, ?webhookUrl:String):Void {
        RPCManager.clientId = clientId;
        RPCManager.webhookUrl = webhookUrl;
        configured = true;
    }

    public static function start():Bool {
        if (!configured) return false;
        sessionStart = Date.now().getTime() / 1000;
        return HxRpc.init(clientId, webhookUrl);
    }

    public static function update(details:String, ?state:String, ?largeImageKey:String, ?largeImageText:String):Bool {
        if (!HxRpc.connected) return false;
        return HxRpc.setActivity({
            details: details,
            state: state,
            largeImageKey: largeImageKey,
            largeImageText: largeImageText,
            startTimestamp: sessionStart
        });
    }

    public static function updateActivity(activity:Activity):Bool {
        if (!HxRpc.connected) return false;
        if (activity.startTimestamp == null) activity.startTimestamp = sessionStart;
        return HxRpc.setActivity(activity);
    }

    public static function clear():Bool {
        if (!HxRpc.connected) return false;
        return HxRpc.clearActivity();
    }

    public static function stop():Void {
        HxRpc.shutdown();
        sessionStart = 0;
    }

    static function get_connected():Bool {
        return HxRpc.connected;
    }
}
