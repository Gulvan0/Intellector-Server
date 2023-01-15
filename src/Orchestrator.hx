package;

import net.shared.PieceColor;
import services.PageManager;
import services.SpecialBroadcaster;
import services.ProfileManager;
import services.Auth;
import entities.Game;
import services.StudyManager;
import net.shared.dataobj.StudyInfo;
import net.shared.dataobj.GameInfo;
import stored.PlayerData;
import services.Storage;
import net.EventTransformer;
import services.GameManager;
import struct.ChallengeParams;
import services.ChallengeManager;
import services.LoginManager;
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
                var isParticipant:Bool = game.log.getColorByRef(author) != null;

                if (isParticipant)
                    game.onPlayerJoined(author);
                else
                    game.onSpectatorJoined(author);

                author.emit(GameIsOngoing(game.getTime(), game.log.get()));

                if (isParticipant)
                    game.resendPendingOffers(author);
            case Past(log):
                author.emit(GameIsOver(log));
            case NonExisting:
                author.emit(GameNotFound);
        }
    }

    public static function processEvent(event:ClientEvent, author:UserSession)
    {
        if (!isEventRelevant(event, author))
        {
            Logger.logError('Skipping irrelevant event ${event.getName()} for author $author (login = ${author.login}, viewedGame = ${author.viewedGameID}, currentFiniteGame = ${author.ongoingFiniteGameID})');
            return;
        }
        
        if (author.storedData != null)
            author.storedData.onMessageReceived();

        switch event 
        {
            case Greet(_, _, _) | KeepAliveBeat | MissedEvents(_) | ResendRequest(_, _):
                Logger.logError('Unexpected event $event from $author');
                return;

            case Login(login, password):
                LoginManager.login(author, login, password);
            case Register(login, password):
                LoginManager.register(author, login, password);
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
                    author.emit(PlayerNotFound);
            case StopFollowing:
                GameManager.stopFollowing(author);

            case Move(_) | Message(_) | Resign | OfferDraw | CancelDraw | AcceptDraw | DeclineDraw | OfferTakeback | CancelTakeback | AcceptTakeback | DeclineTakeback | AddTime:
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
                var challengeData = ChallengeManager.getPublicPendingChallenges().map(x -> x.toChallengeData());
                author.emit(OpenChallenges(challengeData));
            case GetCurrentGames:
                author.emit(CurrentGames(GameManager.getCurrentFiniteTimeGames()));
            case GetRecentGames:
                author.emit(RecentGames(GameManager.getRecentGames()));

            case PageUpdated(page):
                PageManager.updatePage(author, page);
        }
    }

    private static function isEventRelevant(event:ClientEvent, session:UserSession) 
    {
        var logged:Bool = session.login != null;
        var playingFiniteGame:Bool = session.ongoingFiniteGameID != null;
        var viewingGame:Bool = playingFiniteGame || session.viewedGameID != null;

        return switch event 
        {
            case Login(_, _) | Register(_, _): !logged;
            case LogOut | AddFriend(_) | RemoveFriend(_): logged;
            case Move(_) | Message(_) | Resign | OfferDraw | CancelDraw | AcceptDraw | DeclineDraw | OfferTakeback | CancelTakeback | AcceptTakeback | DeclineTakeback | AddTime: viewingGame;
            case CreateChallenge(_) | CancelChallenge(_) | SimpleRematch | CreateStudy(_) | OverwriteStudy(_, _) | DeleteStudy(_): !playingFiniteGame && logged;
            case GetOpenChallenge(_) | FollowPlayer(_) | AcceptChallenge(_) | DeclineDirectChallenge(_) | StopFollowing | GetGame(_) | GetStudy(_) | GetPlayerProfile(_) | GetGamesByLogin(_, _, _, _) | GetStudiesByLogin(_, _, _, _) | GetOngoingGamesByLogin(_) | GetOpenChallenges | GetCurrentGames | GetRecentGames : !playingFiniteGame;
            case Greet(_, _, _) | KeepAliveBeat | MissedEvents(_) | ResendRequest(_, _): false;
            case GetMiniProfile(_) | PageUpdated(_) : true;
        }
    }
}