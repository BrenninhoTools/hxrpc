package rpc;

import discord.Activity;
import discord.Backend;

class HxRpc {
    public static var connected(default, null):Bool = false;
    public static var onConnected:Void->Void;
    public static var onDisconnected:Void->Void;
    public static var onError:String->Void;

    static var backend:Backend;
    static var storedClientId:String;
    static var storedWebhookUrl:String;
    static var current:Activity = {};

    public static function init(clientId:String, ?webhookUrl:String):Bool {
        storedClientId = clientId;
        storedWebhookUrl = webhookUrl;

        #if (windows || mac || linux)
        backend = new discord.native.DiscordIPC();
        #elseif (android || ios)
        backend = new discord.mobile.DiscordWebhook(webhookUrl);
        #else
        backend = null;
        #end

        if (backend == null) {
            connected = false;
            if (onError != null) onError("No backend available for this target");
            return false;
        }

        connected = backend.connect(clientId);

        if (connected) {
            if (onConnected != null) onConnected();
        } else if (onError != null) {
            onError("Failed to connect to Discord");
        }

        return connected;
    }

    public static function reconnect():Bool {
        if (storedClientId == null) {
            if (onError != null) onError("Cannot reconnect before init() was called");
            return false;
        }
        shutdown();
        return init(storedClientId, storedWebhookUrl);
    }

    public static function setActivity(activity:Activity):Bool {
        if (!connected || backend == null) return false;
        current = activity;
        var ok = backend.setActivity(activity);
        if (!ok && onError != null) onError("Failed to set activity");
        return ok;
    }

    public static function setDetails(details:String, ?state:String):Bool {
        current.details = details;
        if (state != null) current.state = state;
        return setActivity(current);
    }

    public static function setState(state:String):Bool {
        current.state = state;
        return setActivity(current);
    }

    public static function setTimestamps(start:Float, ?end:Float):Bool {
        current.startTimestamp = start;
        current.endTimestamp = end;
        return setActivity(current);
    }

    public static function setImages(largeImageKey:String, ?largeImageText:String, ?smallImageKey:String, ?smallImageText:String):Bool {
        current.largeImageKey = largeImageKey;
        current.largeImageText = largeImageText;
        current.smallImageKey = smallImageKey;
        current.smallImageText = smallImageText;
        return setActivity(current);
    }

    public static function setParty(partyId:String, size:Int, max:Int):Bool {
        current.partyId = partyId;
        current.partySize = size;
        current.partyMax = max;
        return setActivity(current);
    }

    public static function setButtons(buttons:Array<{label:String, url:String}>):Bool {
        current.buttons = buttons;
        return setActivity(current);
    }

    public static function clearActivity():Bool {
        if (!connected || backend == null) return false;
        current = {};
        var ok = backend.clearActivity();
        if (!ok && onError != null) onError("Failed to clear activity");
        return ok;
    }

    public static function shutdown():Void {
        if (backend != null) backend.disconnect();
        var wasConnected = connected;
        connected = false;
        backend = null;
        current = {};
        if (wasConnected && onDisconnected != null) onDisconnected();
    }
}
