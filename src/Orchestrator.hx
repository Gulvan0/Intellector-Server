package;

import services.Auth;
import entities.Game;
import services.StudyManager;
import net.shared.StudyInfo;
import net.shared.GameInfo;
import stored.PlayerData;
import services.Storage;
import net.EventTransformer;
import services.GameManager;
import struct.ChallengeParams;
import services.ChallengeManager;
import services.LoginManager;
import entities.util.UserState;
import services.Logger;
import entities.UserSession;
import net.shared.ClientEvent;

class Orchestrator
{
    public static function processEvent(event:ClientEvent, author:UserSession)
    {
        var authorID:String = author.connection.id;
        var authorState:UserState = author.getState();

        Logger.logIncomingEvent(event, authorID, author.login);

        if (!isEventRelevant(event, authorState))
        {
            Logger.logError('Skipping irrelevant event ${event.getName()} for author $authorID (state = ${authorState.getName()})');
            return;
        }
        
        author.storedData.onMessageReceived();

        switch event 
        {
            case Login(login, password):
                LoginManager.login(author, login, password);
            case Register(login, password):
                LoginManager.register(author, login, password);
            case RestoreSession(token):
                Logger.logError('Error: trying to process RestoreSession event inside the Orchestrator method. Token: $token');
            case LogOut:
                LoginManager.logout(author);

            case CreateChallenge(serializedParams):
                ChallengeManager.create(author, ChallengeParams.deserialize(serializedParams));
            case CancelChallenge(challengeID):
                ChallengeManager.cancel(author, challengeID);
            case AcceptChallenge(challengeID):
                ChallengeManager.accept(author, challengeID);
            case DeclineDirectChallenge(challengeID):
                ChallengeManager.decline(author, challengeID);
            case GetOpenChallenge(id):
                ChallengeManager.getOpenChallenge(author, id);

            case FollowPlayer(login):
                if (Auth.userExists(login))
                    GameManager.addFollower(author, login);
                else
                    author.emit(PlayerNotFound); //TODO: Is it processed by client?
            case StopFollowing:
                GameManager.stopFollowing(author);
            case LeaveGame:
                GameManager.leaveGame(author);

            case Move(_, _, _, _, _) | RequestTimeoutCheck | Message(_) | Resign | OfferDraw | CancelDraw | AcceptDraw | DeclineDraw | OfferTakeback | CancelTakeback | AcceptTakeback | DeclineTakeback | AddTime:
                GameManager.processAction(EventTransformer.asGameAction(event), author);

            case SimpleRematch:
                GameManager.simpleRematch(author);

            case CreateStudy(info):
                StudyManager.create(author, info);
            case OverwriteStudy(overwrittenStudyID, info):
                StudyManager.overwrite(author, overwrittenStudyID, info);
            case DeleteStudy(id):
                StudyManager.delete(author, id);

            case GetGame(id):
                switch GameManager.getSimple(id) 
                {
                    case Ongoing(game):
                        author.viewedGameID = id;
                        if (game.log.getColorByLogin(author.login) != null)
                            GameManager.handleReconnection(author);
                        else
                            GameManager.addSpectator(author, id, false);
                        author.emit(GameIsOngoing(game.getTime(), game.log.get()));
                    case Past(log):
                        author.viewedGameID = id;
                        author.emit(GameIsOver(log));
                    case NonExisting:
                        author.emit(GameNotFound);
                }

            case GetStudy(id):
                var info = StudyManager.get(id);
                if (info == null)
                    author.emit(StudyNotFound);
                else
                    author.emit(SingleStudy(info));

            case GetMiniProfile(login):
                if (Auth.userExists(login))
                    author.emit(MiniProfile(Storage.loadPlayerData(login).toMiniProfileData(author.login)));
                else
                    author.emit(PlayerNotFound); //TODO: Is it processed by client?
            case GetPlayerProfile(login):
                if (Auth.userExists(login))
                    author.emit(PlayerProfile(Storage.loadPlayerData(login).toProfileData(author.login)));
                else
                    author.emit(PlayerNotFound);

            case AddFriend(login):
                if (Auth.userExists(login))
                    author.storedData.addFriend(login);
                else
                    author.emit(PlayerNotFound);
            case RemoveFriend(login):
                if (Auth.userExists(login))
                    author.storedData.removeFriend(login);
                else
                    author.emit(PlayerNotFound);

            case GetGamesByLogin(login, after, pageSize, filterByTimeControl):
                if (!Auth.userExists(login))
                {
                    author.emit(PlayerNotFound);
                    return;
                }

                var data:PlayerData = Storage.loadPlayerData(login);
                var games:Array<GameInfo> = data.getPastGames(after, pageSize, filterByTimeControl);
                var hasNext:Bool = data.getPlayedGamesCnt(filterByTimeControl) > after + pageSize;
                author.emit(Games(games, hasNext));

            case GetStudiesByLogin(login, after, pageSize, filterByTags):
                if (!Auth.userExists(login))
                {
                    author.emit(PlayerNotFound);
                    return;
                }

                var data:PlayerData = Storage.loadPlayerData(login);
                var studies = data.getStudies(after, pageSize, filterByTags);
                author.emit(Studies(studies.map, studies.hasNext));

            case GetOngoingGamesByLogin(login):
                if (!Auth.userExists(login))
                {
                    author.emit(PlayerNotFound);
                    return;
                }

                var data:PlayerData = Storage.loadPlayerData(login);
                var gameIDs:Array<Int> = data.getOngoingGameIDs();
                var games:Array<GameInfo> = Storage.getGameInfos(gameIDs);
                author.emit(Games(games, false));
                
            case GetOpenChallenges:
                author.emit(OpenChallenges(ChallengeManager.getPublicChallenges()));
            case GetCurrentGames:
                author.emit(CurrentGames(GameManager.getCurrentFiniteTimeGames()));
        }
    }

    private static function isEventRelevant(event:ClientEvent, state:UserState) 
    {
        if (state.match(AwaitingReconnection))
            return false;

        var logged:Bool = !state.match(NotLogged);
        var viewingGame:Bool = state.match(ViewingGame(_) | PlayingFiniteGame(_));
        var notInGame:Bool = !state.match(PlayingFiniteGame(_));

        return switch event 
        {
            case Login(_, _) | Register(_, _): !logged;
            case LogOut: logged;
            case Move(_, _, _, _, _) | RequestTimeoutCheck | Message(_) | Resign | OfferDraw | CancelDraw | AcceptDraw | DeclineDraw | OfferTakeback | CancelTakeback | AcceptTakeback | DeclineTakeback | AddTime | LeaveGame: viewingGame;
            case CreateChallenge(_) | CancelChallenge(_) | SimpleRematch | CreateStudy(_) | OverwriteStudy(_, _) | DeleteStudy(_): notInGame && logged;
            case GetOpenChallenge(_) | FollowPlayer(_) | AcceptChallenge(_) | DeclineDirectChallenge(_) | StopFollowing | GetGame(_) | GetStudy(_) | GetPlayerProfile(_) | GetGamesByLogin(_, _, _, _) | GetStudiesByLogin(_, _, _, _) | GetOngoingGamesByLogin(_) | GetOpenChallenges | GetCurrentGames: notInGame;
            case RestoreSession(_): false;
            case GetMiniProfile(_) | AddFriend(_) | RemoveFriend(_): true;
        }
    }
}