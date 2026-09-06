package discord;

typedef Activity = {
    ?state:String,
    ?details:String,
    ?startTimestamp:Float,
    ?endTimestamp:Float,
    ?largeImageKey:String,
    ?largeImageText:String,
    ?smallImageKey:String,
    ?smallImageText:String,
    ?partyId:String,
    ?partySize:Int,
    ?partyMax:Int,
    ?buttons:Array<{label:String, url:String}>
}
