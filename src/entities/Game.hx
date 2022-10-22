package entities;

import entities.util.GameLog;
import entities.util.GameState;
import entities.util.GameSessions;
import entities.util.GameOffers;
import services.GameManager;
import utils.ds.DefaultCountMap;
import struct.HexCoords;
import net.shared.ServerEvent;
import net.shared.PieceType;
import struct.Ply;
import struct.Situation;
import net.shared.PieceColor;
import services.Storage;

using StringTools;

abstract class Game 
{
    private var id:Int;

    public var log:GameLog;
    public var offers:GameOffers;
    public var sessions:GameSessions;
    public var state:GameState;

    //TODO: Some methods

    //TODO: Correspondence spectator notification, handle disconnect/connect - how to implement???
}