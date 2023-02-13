package services.util;

import entities.UserSession;

enum GameOpponent
{
    VersusHuman(acceptorSession:UserSession);
    VersusBot(handle:String);
}