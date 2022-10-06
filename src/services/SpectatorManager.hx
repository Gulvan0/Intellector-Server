package services;

import entities.UserSession;

class SpectatorManager
{
    private static var playerFollowersByLogin:Map<String, Array<UserSession>> = [];
    private static var ongoingGameIDBySpectatorLogin:Map<String, Int> = [];

    //TODO: Fill
}