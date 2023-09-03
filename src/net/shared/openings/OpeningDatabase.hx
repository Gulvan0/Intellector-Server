package net.shared.openings;

import net.shared.converters.Notation;
import net.shared.board.RawPly;
import net.shared.board.Situation;
import haxe.Resource;

using StringTools;

class OpeningDatabase
{
    private static var lastID:Int = 0;

    private static var openingsByID:Map<Int, Opening> = [];
    private static var openingsBySIP:Map<String, Opening> = [];

    public static function generate() 
    {
        var contents:String = Resource.getString("openings");
        var lines:Array<String> = contents.split('\n');

        var currentSequence:Array<Situation> = [];

        for (lineIndex => line in lines.keyValueIterator())
        {
            var dashesCnt:Int = 0;
            while (line.charCodeAt(dashesCnt) == "-".code)
                dashesCnt++;

            if (dashesCnt % 2 != 0)
                throw 'Odd number of dashes (openings.tree, line $lineIndex)';

            var level:Int = Std.int(dashesCnt / 2);

            if (currentSequence.length < level)
                throw 'Expected level <= ${currentSequence.length}, got $level (openings.tree, line $lineIndex)';

            currentSequence = currentSequence.slice(0, level);

            var strippedLine:String = line.substr(dashesCnt).trim();

            if (level == 0)
            {
                var situation:Null<Situation> = Situation.deserialize(strippedLine);

                if (situation == null)
                    throw 'Failed to deserialize a situation ($strippedLine in openings.tree, line $lineIndex)';

                currentSequence = [situation];
                continue;
            }

            var parts:Array<String> = strippedLine.split("//");
            var plyStr:String = parts[0].trim();
            var name:Null<String> = parts[1]?.trim();

            var prevSituation:Situation = currentSequence[level-1];
            var ply:Null<RawPly> = Notation.plyFromNotation(plyStr, prevSituation);

            if (ply == null)
                throw 'Failed to deserialize a ply ($plyStr in openings.tree, line $lineIndex)';

            var nextSituation:Situation = prevSituation.situationAfterRawPly(ply);

            if (nextSituation.equals(prevSituation))
                throw 'Failed to perform a ply ($plyStr in openings.tree, line $lineIndex)';

            var symmetricalSituation:Situation = nextSituation.symmetrical();
            var includeSymmetrical:Bool = !nextSituation.equals(symmetricalSituation);

            var prevSIP:String = prevSituation.serialize();
            var nextSIP:String = nextSituation.serialize();
            var symNextSIP:String = symmetricalSituation.serialize();
            var prevOpening:Opening = openingsBySIP.get(prevSIP);

            if (openingsBySIP.exists(nextSIP))
                throw 'Opening already exists: ${openingsBySIP.get(nextSIP).realName} (Encountered again in openings.tree, line $lineIndex)';

            if (openingsBySIP.exists(symNextSIP))
                throw 'Opening already exists: ${openingsBySIP.get(symNextSIP).realName} (Encountered again in openings.tree, line $lineIndex)';

            if (name == "_")
            {
                if (level == 1)
                    throw '_ opening at level 1 ($plyStr in openings.tree, line $lineIndex)';

                var opening:Opening = prevOpening.withContinuation(plyStr, level);

                openingsBySIP.set(nextSIP, opening);

                if (includeSymmetrical)
                {
                    var symmetricalPly:RawPly = ply.symmetrical();
                    var symPlyStr:String = symmetricalPly.toNotation(prevSituation.symmetrical());
                    var symOpening:Opening = prevOpening.withContinuation(symPlyStr, level);
    
                    openingsBySIP.set(symNextSIP, symOpening);
                }
            }
            else if (name == null)
            {
                if (level == 1)
                    throw 'Empty opening at level 1 ($plyStr in openings.tree, line $lineIndex)';

                openingsBySIP.set(nextSIP, prevOpening);

                if (includeSymmetrical)
                    openingsBySIP.set(symNextSIP, prevOpening);
            }
            else
            {
                var hidden:Bool = false;

                var hiddenTag:String = '[h]';

                if (name.startsWith(hiddenTag))
                {
                    hidden = true;
                    name = name.substr(hiddenTag.length).ltrim();
                }

                var opening:Opening = new Opening(lastID, hidden? prevOpening.shownToPlayersName : name, name);
                openingsByID.set(lastID, opening);
                lastID++;

                openingsBySIP.set(nextSIP, opening);

                if (includeSymmetrical)
                    openingsBySIP.set(symNextSIP, opening);
            }

            currentSequence.push(nextSituation);
        }
    }

    public static function get(sip:String):Null<Opening>
    {
        return openingsBySIP.get(sip);
    }

    public static function getByID(id:Int):Null<Opening>
    {
        return openingsByID.get(id);
    }
}