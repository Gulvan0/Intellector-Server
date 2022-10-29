package services.util;

import entities.Game;

enum SimpleAnyGame 
{
    Ongoing(game:Game);
    Past(log:String);    
    NonExisting;
}