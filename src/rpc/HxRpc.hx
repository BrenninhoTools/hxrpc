package rpc;

import discord.Activity;
import discord.Backend;

class HxRpc {
    public static var connected(default, null):Bool = false;

    static var backend:Backend;

    public static function init(clientId:String, ?webhookUrl:String):Bool {
        #if (windows || mac || linux)
        backend = new discord.native.DiscordIPC();
        connected = backend.connect(clientId);
        #elseif (android || ios)
        backend = new discord.mobile.DiscordWebhook(webhookUrl);
        connected = backend.connect(clientId);
        #else
        backend = null;
        connected = false;
        #end
        return connected;
    }

    public static function setActivity(activity:Activity):Bool {
        if (!connected || backend == null) return false;
        return backend.setActivity(activity);
    }

    public static function clearActivity():Bool {
        if (!connected || backend == null) return false;
        return backend.clearActivity();
    }

    public static function shutdown():Void {
        if (backend != null) backend.disconnect();
        connected = false;
        backend = null;
    }
}
