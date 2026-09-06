package mobilerpc;

import discord.Activity;
import discord.mobile.DiscordWebhook;

class DiscordMobile {
    public static var connected(default, null):Bool = false;

    static var backend:DiscordWebhook;
    static var sessionStart:Float;

    public static function init(webhookUrl:String):Bool {
        backend = new DiscordWebhook(webhookUrl);
        connected = backend.connect(webhookUrl);
        sessionStart = Date.now().getTime() / 1000;
        return connected;
    }

    public static function update(details:String, ?state:String):Bool {
        if (!connected || backend == null) return false;
        return backend.setActivity({
            details: details,
            state: state,
            startTimestamp: sessionStart
        });
    }

    public static function updateActivity(activity:Activity):Bool {
        if (!connected || backend == null) return false;
        return backend.setActivity(activity);
    }

    public static function clear():Bool {
        if (!connected || backend == null) return false;
        return backend.clearActivity();
    }

    public static function shutdown():Void {
        if (backend != null) backend.disconnect();
        connected = false;
        backend = null;
    }
}
