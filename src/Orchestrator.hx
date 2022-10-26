package;

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
                GameManager.addFollower(author, login);
            case StopFollowing:
                GameManager.stopFollowing(author);
            case StopSpectating:
                GameManager.stopSpectating(author);

            case Move(gameID, _, _, _, _, _) | RequestTimeoutCheck(gameID) | Message(gameID, _) | Resign(gameID) | OfferDraw(gameID) | CancelDraw(gameID) | AcceptDraw(gameID) | DeclineDraw(gameID) | OfferTakeback(gameID) | CancelTakeback(gameID) | AcceptTakeback(gameID) | DeclineTakeback(gameID) | AddTime(gameID):
                GameManager.processAction(gameID, EventTransformer.asGameAction(event), author);

            case SimpleRematch(gameID):
                GameManager.simpleRematch(author, gameID);

            case CreateStudy(info):
            case OverwriteStudy(overwrittenStudyID, info):
            case DeleteStudy(id):

            case GetGame(id):
            case GetStudy(id):

            case GetMiniProfile(login):
                author.emit(MiniProfile(Storage.loadPlayerData(login).toMiniProfileData(author.login)));
            case GetPlayerProfile(login):
                author.emit(PlayerProfile(Storage.loadPlayerData(login).toProfileData(author.login)));

            case AddFriend(login):
                author.storedData.addFriend(login);
            case RemoveFriend(login):
                author.storedData.removeFriend(login);

            case GetGamesByLogin(login, after, pageSize, filterByTimeControl):
                var data:PlayerData = Storage.loadPlayerData(login);
                var games:Array<GameInfo> = data.getPastGames(after, pageSize, filterByTimeControl);
                var hasNext:Bool = data.getPlayedGamesCnt(filterByTimeControl) > after + pageSize;
                author.emit(Games(games, hasNext));
            case GetStudiesByLogin(login, after, pageSize, filterByTags):
                var data:PlayerData = Storage.loadPlayerData(login);
                var studies = data.getStudies(after, pageSize, filterByTags);
                author.emit(Studies(studies.map, studies.hasNext));
            case GetOngoingGamesByLogin(login):
                var data:PlayerData = Storage.loadPlayerData(login);
                var games:Array<GameInfo> = data.getOngoingGames();
                author.emit(Games(games, false));
                
            case GetOpenChallenges:
            case GetCurrentGames:
        }
    }

    private static function isEventRelevant(event:ClientEvent, state:UserState) 
    {
        var possibleStates:Array<UserState> = switch event 
        {
            case Login(_, _): [NotLogged];
            case Register(_, _): [NotLogged];
            case RestoreSession(_): [];
            case LogOut: [Browsing, InGame];
            case CreateChallenge(_): [Browsing];
            case CancelChallenge(_): [Browsing]; 
            case AcceptChallenge(_): [NotLogged, Browsing];
            case DeclineDirectChallenge(_): [Browsing];
            case Move(_, _, _, _, _, _): [InGame];
            case RequestTimeoutCheck(_): [InGame];
            case Message(_, _): [NotLogged, Browsing, InGame];
            case GetOpenChallenge(_): [NotLogged, Browsing];
            case FollowPlayer(_): [NotLogged, Browsing];
            case StopSpectating: [NotLogged, Browsing];
            case StopFollowing: [NotLogged, Browsing];
            case Resign(_): [InGame];
            case OfferDraw(_): [InGame];
            case CancelDraw(_): [InGame];
            case AcceptDraw(_): [InGame];
            case DeclineDraw(_): [InGame];
            case OfferTakeback(_): [InGame];
            case CancelTakeback(_): [InGame];
            case AcceptTakeback(_): [InGame];
            case DeclineTakeback(_): [InGame];
            case AddTime(_): [InGame];
            case SimpleRematch(_): [Browsing];
            case CreateStudy(_): [Browsing];
            case OverwriteStudy(_, _): [Browsing];
            case DeleteStudy(_): [Browsing];
            case GetGame(_): [NotLogged, Browsing];
            case GetStudy(_): [NotLogged, Browsing];
            case GetMiniProfile(_): [NotLogged, Browsing];
            case GetPlayerProfile(_): [NotLogged, Browsing];
            case AddFriend(_): [Browsing];
            case RemoveFriend(_): [Browsing];
            case GetGamesByLogin(_, _, _, _): [NotLogged, Browsing];
            case GetStudiesByLogin(_, _, _, _): [NotLogged, Browsing];
            case GetOngoingGamesByLogin(_): [NotLogged, Browsing];
            case GetOpenChallenges: [NotLogged, Browsing];
            case GetCurrentGames: [NotLogged, Browsing];
        }
        return possibleStates.contains(state);
    }
}