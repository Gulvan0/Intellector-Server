package services;

import net.shared.dataobj.ChallengeData;
import net.shared.dataobj.GameInfo;
import net.shared.ServerEvent;
import utils.ds.DefaultArrayMap;
import net.shared.dataobj.ViewedScreen;
import entities.UserSession;

class PageManager 
{
    private static var pageBySessionID:Map<Int, ViewedScreen> = [];
    private static var sessionsByPage:DefaultArrayMap<ViewedScreen, UserSession> = new DefaultArrayMap([]);

    public static function getPage(session:UserSession):Null<ViewedScreen>
    {
        return pageBySessionID.get(session.sessionID);
    }

    public static function updatePage(session:UserSession, page:ViewedScreen) 
    {
        var previousPage = getPage(session);

        if (previousPage != null)
            if (samePage(previousPage, page))
                return;
            else
            {
                sessionsByPage.pop(previousPage, session);
                onPageLeft(session, previousPage, false);
            }

        pageBySessionID.set(session.sessionID, page);
        sessionsByPage.push(page, session);

        onPageEntered(session, page);
    }

    public static function handleSessionDestruction(session:UserSession) 
    {
        var previousPage = getPage(session);
        if (previousPage != null)
        {
            onPageLeft(session, previousPage, true);
            sessionsByPage.pop(previousPage, session);
        }

        pageBySessionID.remove(session.sessionID);
    }

    public static function notifyPageViewers(page:ViewedScreen, event:ServerEvent) 
    {
        for (session in sessionsByPage.get(page))
            session.emit(event);
    }

    private static function onPageLeft(session:UserSession, page:ViewedScreen, wasLastPage:Bool) 
    {
        switch page 
        {
            case MainMenu:
                //* Do nothing
            case Game(id):
                if (!wasLastPage)
                {
                    Logger.serviceLog('GAMEMGR', '$session leaves game $id');

                    switch GameManager.getSimple(id) 
                    {
                        case Ongoing(game):
                            game.onUserLeftToOtherPage(session);
                        default:
                    }
                }
            case Analysis:
                //* Do nothing
            case Profile(ownerLogin):
                //* Do nothing
            case Other:
                //* Do nothing
        }
    }

    private static function onPageEntered(session:UserSession, page:ViewedScreen) 
    {
        switch page 
        {
            case MainMenu:
                var challenges:Array<ChallengeData> = ChallengeManager.getPublicPendingChallenges().map(x -> x.toChallengeData());
                var currentGames:Array<GameInfo> = GameManager.getCurrentFiniteTimeGames();
                var recentGames:Array<GameInfo> = GameManager.getRecentGames();
                session.emit(MainMenuData(challenges, currentGames, recentGames));
            case Game(id):
                //* Do nothing (spectation, participation, other things are processed in the other managers)
            case Analysis:
                //* Do nothing
            case Profile(ownerLogin):
                //* Do nothing
            case Other:
                //* Do nothing
        }
    }

    private static function samePage(screen1:ViewedScreen, screen2:ViewedScreen):Bool
    {
        return switch screen1 
        {
            case MainMenu: screen2 == MainMenu;
            case Game(id1): switch screen2 
            {
                case Game(id2): id1 == id2;
                default: false;
            }
            case Analysis: screen2 == Analysis;
            case Profile(ownerLogin1): switch screen2 
            {
                case Profile(ownerLogin2): ownerLogin1.toLowerCase() == ownerLogin2.toLowerCase();
                default: false;
            }
            case Other: screen2 == Other;
        }
    }
}