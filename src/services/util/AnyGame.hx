package services.util;

import entities.CorrespondenceGame;
import entities.FiniteTimeGame;

enum AnyGame
{
    OngoingFinite(game:FiniteTimeGame);
    OngoingCorrespondence(game:CorrespondenceGame);
    Past(log:String);
    NonExisting;
}