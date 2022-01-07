package subsystems;

import haxe.Json;
import sys.io.Process;
using StringTools;

typedef GameOverview = 
{
    var id:Int;
    var whiteLogin:String;
    var blackLogin:String;
    var winnerColorLetter:String;
    var outcomeCode:String;
}

typedef StudyOverview = 
{
    var id:Int;
    var data:StudyData;
}

typedef StudyData = 
{
    var name:String;
    var author:String;
    var variantStr:String;
    var startingSIP:String;
}

class Librarian 
{
    public static function getGamesByPlayer(socket:SocketHandler, login:String, pageSize:Int, after:Int)
    {
        if (!Data.playerdataExists(login))
        {
            socket.emit('player_not_found', {});
            return;
        }

        var playersRegexp:EReg = ~/#P\|(.*?):(.*?);/;
        var resultRegexp:EReg = ~/#R\|([wbd])\/(...)/;

        var gamelist:Array<GameOverview> = [];
        var allGameIDs:Array<Int> = Data.getPlayerdata(login).games;
        var currentGame = GameManager.getGameByLogin(login);
        if (currentGame != null)
            allGameIDs.remove(currentGame.id);

        for (gameID in allGameIDs.slice(after, after + pageSize))
        {
            var log:String = Data.getLog(gameID);
            playersRegexp.match(log);
            resultRegexp.match(log);
            gamelist.push({
                id: gameID,
                whiteLogin: playersRegexp.matched(1),
                blackLogin: playersRegexp.matched(2),
                winnerColorLetter: resultRegexp.matched(1),
                outcomeCode: resultRegexp.matched(2)
            });
        }
        socket.emit('games_list', Json.stringify(gamelist));
    }    

    public static function getStudiesByPlayer(socket:SocketHandler, login:String, pageSize:Int, after:Int)
    {
        if (!Data.playerdataExists(login))
        {
            socket.emit('player_not_found', {});
            return;
        }

        var studylist:Array<StudyOverview> = [];
        for (id in Data.getPlayerdata(login).studies.slice(after, after + pageSize))
        {
            studylist.push({
                id: id,
                data: Data.getStudy(id)
            });
        }
        socket.emit('studies_list', Json.stringify(studylist));
    }  

    public static function setStudy(socket:SocketHandler, login:String, name:String, variantStr:String, startingSIP:String, overwriteID:Null<Int>)
    {
        if (!Data.playerdataExists(login))
            return;

        if (overwriteID == null)
            createStudy(login, name, variantStr, startingSIP);
        else if (Data.studyExists(overwriteID))
        {
            var studyData:StudyData = Data.getStudy(overwriteID);
            var newStudyData:StudyData = {
                name: name,
                author: login,
                variantStr: variantStr,
                startingSIP: startingSIP
            };
            if (studyData.author == login)
                Data.writeStudy(overwriteID, newStudyData);
        }
    }

    private static function createStudy(login:String, name:String, variantStr:String, startingSIP:String) 
    {
        var currID:Int = Data.getCurrID(Studies);
        var data:StudyData = {
            name: name,
            author: login,
            variantStr: variantStr,
            startingSIP: startingSIP
        };
        Data.writeStudy(currID, data);
        Data.editPlayerdata(login, pd -> {
            pd.studies = [currID].concat(pd.studies);
            return pd;
        });
    }
}