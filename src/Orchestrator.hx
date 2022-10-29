package;

import services.ProfileManager;
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
    private static function processGetGameRequest(author:UserSession, id:Int) 
    {
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
    }

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

            case GetStudy(id):
                StudyManager.get(author, id);
            case CreateStudy(info):
                StudyManager.create(author, info);
            case OverwriteStudy(overwrittenStudyID, info):
                StudyManager.overwrite(author, overwrittenStudyID, info);
            case DeleteStudy(id):
                StudyManager.delete(author, id);

            case GetGame(id):
                processGetGameRequest(author, id);

            case GetMiniProfile(login):
                ProfileManager.getMiniProfile(author, login);
            case GetPlayerProfile(login):
                ProfileManager.getProfile(author, login);

            case AddFriend(login):
                ProfileManager.addFriend(author, login);
            case RemoveFriend(login):
                ProfileManager.removeFriend(author, login);

            case GetGamesByLogin(login, after, pageSize, filterByTimeControl):
                ProfileManager.getPastGames(author, login, after, pageSize, filterByTimeControl);
            case GetStudiesByLogin(login, after, pageSize, filterByTags):
                ProfileManager.getStudies(author, login, after, pageSize, filterByTags);
            case GetOngoingGamesByLogin(login):
                ProfileManager.getOngoingGames(author, login);
                
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