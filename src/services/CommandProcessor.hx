package services;

import services.util.AnyGame;
import entities.Game;
import utils.MathUtils;
import services.Storage.LogType;
import entities.UserSession;

using StringTools;

class CommandProcessor 
{ 
    private static var logEntryHeaderRegex:EReg = ~/### ([^#]*?) ###/;

    public static function processCommand(rawText:String, callback:String->Void) 
    {
        var parts = rawText.split(' ');
        var command = parts[0];
        var args = parts.slice(1);

        Logger.serviceLog('COMMAND', 'Executing command: $rawText');

        try 
        {
            switch command 
            {
                case "logged":
                    var users:Array<UserSession> = LoginManager.getLoggedUsers();
                    callback(users.map(x -> x.login).toString());
                case "log":
                    if (args.length > 0)
                    {
                        var logText:String = Storage.read(Log(LogType.createByName(args[0])));
                        var lines:Array<String> = logText.split('\n');

                        var readFrom:String = args.length > 1? args[1] : "1970-01-01";
                        var readTo:String = args.length > 2? args[2] : "2099-12-12";

                        var i:Int = lines.length - 1;
                        var currentEntry:String = "";

                        callback('Reading logs from $readFrom to $readTo');

                        while (i >= 0)
                        {
                            var line:String = lines[i];

                            currentEntry = line + '\n' + currentEntry;

                            if (logEntryHeaderRegex.match(line))
                            {
                                var dateStr:String = logEntryHeaderRegex.matched(1);
                                if (dateStr < readFrom)
                                    break;
                                else if (dateStr <= readTo)
                                    callback(currentEntry);

                                currentEntry = "";
                            }

                            i--;
                        }
                    }
                case "games":
                    for (gameInfo in GameManager.getCurrentFiniteTimeGames())
                    {
                        var anyGame:AnyGame = GameManager.get(gameInfo.id);

                        switch anyGame 
                        {
                            case OngoingFinite(game):
                                var desc:String = 'Game ${gameInfo.id}\n';
                                desc += game.log.getEntries().map(Std.string).join('\n');
                                desc += 'Time left: White ' + MathUtils.roundTo(game.getTime().whiteSeconds, -2) + 's, Black ' + MathUtils.roundTo(game.getTime().blackSeconds, -2) + 's';
                                callback(desc);
                            case OngoingCorrespondence(game):
                                callback('Oops! Game with ID ${gameInfo.id} is considered finite, but is actually correspondence');
                            case Past(log):
                                callback('Oops! Game with ID ${gameInfo.id} is considered ongoing, but has actually already ended');
                            case NonExisting:
                                callback('Oops! Game with ID ${gameInfo.id} is considered ongoing, but actually does not exist');
                        }
                    }
                case "challenges":
                    var challenges = ChallengeManager.getAllPendingChallenges();

                    if (Lambda.empty(challenges))
                        callback('No challenges found');
                    else
                        for (challengeInfo in challenges)
                        {
                            var desc:String = 'Challenge ${challengeInfo.id} by ${challengeInfo.ownerLogin}\n';
                            desc += 'Type: ${challengeInfo.params.type}\n';
                            desc += 'Time control: ${challengeInfo.params.timeControl.toString(false)}\n';
                            desc += 'Rated: ${challengeInfo.params.rated}\n';
                            if (challengeInfo.params.customStartingSituation != null)
                                desc += 'Custom SIP: ${challengeInfo.params.customStartingSituation.serialize()}\n';
                            desc += 'Acceptor color: ${challengeInfo.params.acceptorColor}';
                            callback(desc);
                        }
                case "profile":
                    if (args.length > 0)
                        callback(Storage.read(PlayerData(args[0].toLowerCase())));
                case "game":
                    if (args.length > 0)
                        callback(Storage.read(GameData(Std.parseInt(args[0]))));
                case "kick":
                    if (args.length > 0)
                        LoginManager.getUser(args[0].toLowerCase()).abortConnection(true);
                case "pwd":
                    if (args.length > 1)
                        Auth.addCredentials(args[0], args[1]);
                default:
                    callback("Malformed command");
            }
        }
        catch (e)
        {
            trace(e.details());
            callback(e.details());
        }
    }
}