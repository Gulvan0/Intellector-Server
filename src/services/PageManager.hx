package services;

import net.shared.ServerEvent;
import utils.ds.DefaultArrayMap;
import net.shared.dataobj.ViewedScreen;
import entities.UserSession;

class PageManager 
{
    private static var pageByUserRef:Map<String, ViewedScreen> = [];
    private static var sessionsByPage:DefaultArrayMap<ViewedScreen, UserSession> = new DefaultArrayMap([]);

    public static function getPage(session:UserSession):Null<ViewedScreen>
    {
        return pageByUserRef.get(session.getInteractionReference());
    }

    public static function updatePage(session:UserSession, page:ViewedScreen) 
    {
        var previousPage = getPage(session);
        if (previousPage != null)
            onPageLeft(session, previousPage);

        pageByUserRef.set(session.getInteractionReference(), page);
        sessionsByPage.push(page, session);

        onPageEntered(session, page);
    }

    public static function handleSessionDestruction(session:UserSession) 
    {
        var previousPage = getPage(session);
        if (previousPage != null)
        {
            onPageLeft(session, previousPage);
            sessionsByPage.pop(previousPage, session);
        }

        pageByUserRef.remove(session.getInteractionReference());
    }

    public static function notifyPageViewers(page:ViewedScreen, event:ServerEvent) 
    {
        for (session in sessionsByPage.get(page))
            session.emit(event);
    }

    private static function onPageLeft(session:UserSession, page:ViewedScreen) 
    {
        switch page 
        {
            case MainMenu:
                //* Do nothing
            case Game(id):
                GameManager.leaveGame(session, id);
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
                session.emit(MainMenuData(ChallengeManager.getPublicChallenges(), GameManager.getCurrentFiniteTimeGames(), GameManager.getRecentGames()));
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
}