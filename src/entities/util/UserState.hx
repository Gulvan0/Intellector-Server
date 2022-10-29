package entities.util;

enum UserState
{
    AwaitingReconnection;
    NotLogged;
    Browsing;
    ViewingGame(gameID:Int); //Either viewing own ongoing correspondence game, spectating any ongoing game or viewing past game
    PlayingFiniteGame(gameID:Int);
}