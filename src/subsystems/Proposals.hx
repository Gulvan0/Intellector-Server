package subsystems;

enum ProposalType
{
    Draw;
    Takeback;
}

enum ProposalAction
{
    Offer;
    Cancel;
    Accept;
    Decline;
}

class Proposals 
{
    private static var eventNamePrefixes:Map<ProposalType, String> = [
        Draw => 'draw',
        Takeback => 'takeback'
    ];
    private static var eventNamePostfixes:Map<ProposalAction, String> = [
        Offer => 'offered',
        Cancel => 'cancelled',
        Accept => 'accepted',
        Decline => 'declined'
    ];

    private static var loggedPlayers:Map<String, SocketHandler>;
	private static var games:Map<String, Game> = [];

    public static function init(loggedPlayersMap:Map<String, SocketHandler>, gamesMap:Map<String, Game>) 
    {
        loggedPlayers = loggedPlayersMap;   
        games = gamesMap;
    }

    public static function eventName(type:ProposalType, action:ProposalAction) 
    {
        return eventNamePrefixes[type] + '_' + eventNamePostfixes[action];
    }

    //---------------------------------------------------------------------------------------------------------------
    
    public static function offer(socket:SocketHandler, type:ProposalType) 
    {
        var game:Game = games.get(socket.login);
        if (game == null)
            return;

        var pendingOfferer:String = game.pendingOfferer.get(type);

        if (pendingOfferer == null)
        {
            var letter = type == Draw? "d" : "t";
            game.log += "#E|" + letter + "of\n";
            game.pendingOfferer[type] = socket.login;
            forwardEvent(game.getOpponent(socket.login), type, Offer);
        }
        else if (pendingOfferer != socket.login)
            acceptProposal(game, type);
    }

    public static function cancel(socket:SocketHandler, type:ProposalType) 
    {
        var game:Game = games.get(socket.login);
        if (game == null)
            return;

        var letter = type == Draw? "d" : "t";
        game.log += "#E|" + letter + "ca\n";

        game.pendingOfferer[type] = null;
        forwardEvent(game.getOpponent(socket.login), type, Cancel);
    }

    public static function accept(socket:SocketHandler, type:ProposalType) 
    {
        var game:Game = games.get(socket.login);
        if (game == null || !game.pendingOfferer.exists(type))
            return;

        acceptProposal(game, type);
    }

    public static function decline(socket:SocketHandler, type:ProposalType) 
    {
        var game:Game = games.get(socket.login);
        if (game == null || !game.pendingOfferer.exists(type))
            return;

        var letter = type == Draw? "d" : "t";
        game.log += "#E|" + letter + "de\n";

        game.pendingOfferer[type] = null;
        forwardEvent(game.getOpponent(socket.login), type, Decline);
    }

    //----------------------------------------------------------------------------------------------------------------------

    private static function acceptProposal(game:Game, type:ProposalType) 
    {
        var offererLogin = game.pendingOfferer.get(type);
        if (offererLogin == null)
            return;

        var letter = type == Draw? "d" : "t";
        game.log += "#E|" + letter + "ac\n";

        forwardEvent(offererLogin, type, Accept);

        switch type 
        {
            case Draw: acceptDraw(game);
            case Takeback: acceptTakeback(game, offererLogin);
        }
    }

    private static function acceptDraw(game:Game) 
    {
        GameManager.endGame(DrawAgreement, game);
    }

    private static function acceptTakeback(game:Game, offerer:String) 
    {
        game.pendingOfferer[Takeback] = null;

        var cnt = game.getPlayerToMove() == offerer? 2 : 1;
        game.revertMoves(cnt);

        for (playerLogin in [game.whiteLogin, game.blackLogin])
        {
            var playerSocket = loggedPlayers.get(playerLogin);
            if (playerSocket != null)
                playerSocket.emit('rollback', cnt);
        }
        for (spec in game.whiteSpectators.concat(game.blackSpectators))
            if (spec != null)
                spec.emit('rollback', cnt);
    }

    private static function forwardEvent(receiverLogin:String, type:ProposalType, action:ProposalAction) 
    {
        var socket = loggedPlayers.get(receiverLogin);
        var event = eventName(type, action);
        if (socket != null)
            socket.emit(event, {});
    }
}