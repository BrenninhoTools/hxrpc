package discord.web;

import discord.Activity;
import discord.Backend;
import haxe.Http;
import haxe.Json;

class WebRPC implements Backend {
    var url:String;

    public function new(url:String) {
        this.url = url;
    }

    public function connect(clientId:String):Bool {
        return url != null && url.length > 0;
    }

    public function setActivity(activity:Activity):Bool {
        if (url == null) return false;

        var description = new StringBuf();
        if (activity.details != null) description.add(activity.details);
        if (activity.state != null) {
            if (description.length > 0) description.add("\n");
            description.add(activity.state);
        }

        var embed = {
            title: "Now Playing",
            description: description.toString(),
            color: 0x5865F2,
            timestamp: Date.now().toString()
        };

        post({embeds: [embed]});
        return true;
    }

    public function clearActivity():Bool {
        if (url == null) return false;
        post({content: "Stopped playing.", embeds: []});
        return true;
    }

    public function disconnect():Void {}

    function post(payload:Dynamic):Void {
        var http = new Http(url);
        http.setHeader("Content-Type", "application/json");
        http.setPostData(Json.stringify(payload));
        http.onError = function(_) {};
        http.request(true);
    }
}
