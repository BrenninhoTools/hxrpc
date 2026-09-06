package discord.ai;

import discord.Activity;
import haxe.Timer;
import rpc.HxRpc;

typedef AiPromptRule = {
    var keyword:String;
    var details:String;
    var state:String;
    var ?largeImageKey:String;
    var ?largeImageText:String;
    var ?smallImageKey:String;
    var ?smallImageText:String;
}

class DiscordAI {
    public static var enabled(default, null):Bool = false;
    public static var updateInterval:Float = 10.0;
    public static var autoContextSwitch:Bool = true;

    static var rules:Array<AiPromptRule> = [];
    static var fallbackDetails:String = "Idle";
    static var fallbackState:String = "Waiting for actions...";

    static var aiTimer:Timer;
    static var currentContext:String = "";
    static var dynamicStatsProvider:Void->Dynamic;

    public static function init(defaultDetails:String, defaultState:String, ?intervalSeconds:Float = 10.0):Void {
        fallbackDetails = defaultDetails;
        fallbackState = defaultState;
        updateInterval = intervalSeconds;
        enabled = true;

        startProcessingLoop();
    }

    public static function registerRule(rule:AiPromptRule):Void {
        if (rule == null || rule.keyword == null) return;
        rules.push(rule);
    }

    public static function setStatsProvider(provider:Void->Dynamic):Void {
        dynamicStatsProvider = provider;
    }

    public static function analyzeContext(contextPrompt:String):Void {
        if (!enabled || contextPrompt == null) return;

        currentContext = contextPrompt.toLowerCase();
        processCurrentContext();
    }

    public static function stop():Void {
        if (aiTimer != null) {
            aiTimer.stop();
            aiTimer = null;
        }
        enabled = false;
        rules = [];
        dynamicStatsProvider = null;
        currentContext = "";
    }

    static function startProcessingLoop():Void {
        if (aiTimer != null) {
            aiTimer.stop();
        }

        var delay:Int = Std.int(updateInterval * 1000);
        aiTimer = new Timer(delay);
        aiTimer.run = function() {
            if (enabled && HxRpc.connected) {
                processCurrentContext();
            }
        };
    }

    static function processCurrentContext():Void {
        var matchedRule:AiPromptRule = findBestRule(currentContext);

        var finalDetails:String = fallbackDetails;
        var finalState:String = fallbackState;
        var largeKey:Null<String> = null;
        var largeTxt:Null<String> = null;
        var smallKey:Null<String> = null;
        var smallTxt:Null<String> = null;

        if (matchedRule != null) {
            finalDetails = matchedRule.details;
            finalState = matchedRule.state;
            largeKey = matchedRule.largeImageKey;
            largeTxt = matchedRule.largeImageText;
            smallKey = matchedRule.smallImageKey;
            smallTxt = matchedRule.smallImageText;
        }

        if (dynamicStatsProvider != null) {
            var stats:Dynamic = dynamicStatsProvider();
            if (stats != null) {
                if (Reflect.hasField(stats, "details")) finalDetails = Reflect.field(stats, "details");
                if (Reflect.hasField(stats, "state")) finalState = Reflect.field(stats, "state");
            }
        }

        HxRpc.setActivity({
            details: finalDetails,
            state: finalState,
            largeImageKey: largeKey,
            largeImageText: largeTxt,
            smallImageKey: smallKey,
            smallImageText: smallTxt
        });
    }

    static function findBestRule(context:String):AiPromptRule {
        if (context == "" || rules.length == 0) return null;

        for (rule in rules) {
            if (context.indexOf(rule.keyword.toLowerCase()) != -1) {
                return rule;
            }
        }
        return null;
    }
}
