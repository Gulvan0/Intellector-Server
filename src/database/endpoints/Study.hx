package database.endpoints;

import net.shared.variation.VariationPath;
import net.shared.board.RawPly;
import net.shared.variation.VariationMap;
import net.shared.board.Situation;
import net.shared.dataobj.StudyPublicity;
import database.returned.GetStudyResult;
import database.returned.DeleteStudyResult;
import net.shared.variation.PlainVariation;
import database.returned.OverwriteStudyResult;
import sys.db.ResultSet;
import net.shared.utils.PlayerRef;
import database.special_values.Timestamp;
import net.shared.dataobj.StudyInfo;

using database.ScalarGetters;

private enum StandardModificationChecksResult 
{
    Nonexistent;
    Unauthorized;
    Passed;
}

class Study 
{
    private static function constructVariationRows(studyID:Int, plainVariation:PlainVariation):Array<Array<Dynamic>> 
    {
        var variationRows:Array<Array<Dynamic>> = [];

        for (joinedPath => ply in plainVariation.getPlys().asStringMap().keyValueIterator())
            variationRows.push([studyID, joinedPath, ply.from.toScalarCoord(), ply.to.toScalarCoord(), ply.morphInto]);

        return variationRows;
    }

    private static function constructTagRows(studyID:Int, tags:Array<String>):Array<Array<Dynamic>> 
    {
        return tags.map(tag -> [studyID, tag]);
    }

    private static function performStandardModificationChecks(id:Int, requestedBy:PlayerRef):StandardModificationChecksResult
    {
        var set:ResultSet = Database.instance.filter("study.study", [Conditions.equals("id", id)], ["author_login"]);

        if (!set.hasNext())
        {
            Logging.info("Study.performStdModifyChks()", 'Study does not exist (ID = $id)');
            return Nonexistent;
        }

        var authorLogin:String = set.getScalarString();

        if (!requestedBy.equals(authorLogin))
        {
            Logging.info("Study.performStdModifyChks()", 'Cannot overwrite study (ID = $id) because requesting player $requestedBy is not the same as the study\'s author $authorLogin');
            return Unauthorized;
        }

        return Passed;
    }

    public static function create(info:StudyInfo)
    {
        var studyRow:Array<Dynamic> = [
            null,
            CurrentTimestamp,
            CurrentTimestamp,
            info.ownerLogin,
            info.name,
            info.description,
            info.publicity,
            info.plainVariation.getStartingSituation(),
            info.keyPositionSIP,
            false
        ];

        Database.instance.startTransaction();

        var result:QueryExecutionResult = Database.instance.insertRow("study.study", studyRow, true);

        var studyID:Int = result.lastID;

        Database.instance.insertRows("study.study_tag", constructTagRows(studyID, info.tags), false);
        Database.instance.insertRows("study.variation_node", constructVariationRows(studyID, info.plainVariation), false);

        Database.instance.commit();

        Logging.info("e:Study.create()", 'Study created (ID = $studyID)');

        return studyID;
    }

    public static function overwrite(id:Int, info:StudyInfo, requestedBy:PlayerRef):OverwriteStudyResult 
    {
        switch performStandardModificationChecks(id, requestedBy) 
        {
            case Nonexistent:
                return Nonexistent;
            case Unauthorized:
                return Unauthorized;
            case Passed:
                //* Just continue
        }

        var filteringConditions:Array<String> = [Conditions.equals("id", id)];

        var updates:Map<String, Dynamic> = [
            "modified_at" => CurrentTimestamp,
            "study_name" => info.name,
            "study_description" => info.description,
            "publicity" => info.publicity,
            "starting_sip" => info.plainVariation.getStartingSituation(),
            "key_position_sip" => info.keyPositionSIP,
            "deleted" => false
        ];

        Database.instance.startTransaction();

        Database.instance.update("study.study", updates, filteringConditions);

        Database.instance.delete("study.study_tag", filteringConditions);
        Database.instance.insertRows("study.study_tag", constructTagRows(id, info.tags), false);

        Database.instance.delete("study.variation_node", filteringConditions);
        Database.instance.insertRows("study.variation_node", constructVariationRows(id, info.plainVariation), false);

        Database.instance.commit();
        
        Logging.info("e:Study.overwrite()", 'Study overwritten (ID = $id; requested by $requestedBy)');
        return Overwritten;
    }

    public static function delete(id:Int, requestedBy:PlayerRef):DeleteStudyResult 
    {
        switch performStandardModificationChecks(id, requestedBy) 
        {
            case Nonexistent:
                return Nonexistent;
            case Unauthorized:
                return Unauthorized;
            case Passed:
                //* Just continue
        }

        var filteringConditions:Array<String> = [Conditions.equals("id", id)];

        var updates:Map<String, Dynamic> = [
            "deleted" => true
        ];

        Database.instance.update("study.study", updates, filteringConditions);
        
        Logging.info("e:Study.overwrite()", 'Study detached (ID = $id; requested by $requestedBy)');
        return Deleted;
    }

    public static function getStudy(id:Int, requestedBy:PlayerRef):GetStudyResult 
    {
        var filteringConditions:Array<String> = [Conditions.equals("id", id)];

        var set:ResultSet = Database.instance.filter("study.study", filteringConditions);

        if (!set.hasNext())
        {
            Logging.info("Study.getStudy()", 'Study does not exist (ID = $id)');
            return Nonexistent;
        }

        var row:ResultRow = set.next();

        var publicity:StudyPublicity = row.getStudyPublicity("publicity");
        var authorLogin:PlayerRef = row.getPlayerRef("author_login");

        if (publicity.match(Private) && !authorLogin.equals(requestedBy))
            return Unauthorized;

        var studyInfo:StudyInfo = new StudyInfo();

        studyInfo.id = id;
        studyInfo.ownerLogin = authorLogin;
        studyInfo.name = row.getString("study_name");
        studyInfo.description = row.getString("study_description");
        studyInfo.publicity = publicity;
        studyInfo.keyPositionSIP = row.getString("key_position_sip");

        studyInfo.tags = [];

        var tagSet:ResultSet = Database.instance.filter("study.study_tag", filteringConditions, ["tag"]);
        for (i in 0...tagSet.length)
            studyInfo.tags.push(tagSet.getResult(i));

        var startingSituation:Situation = row.getSituation("starting_sip");
        var plys:VariationMap<RawPly> = new VariationMap<RawPly>();

        var nodeSet:ResultSet = Database.instance.filter("study.variation_node", filteringConditions);
        for (nodeRow in nodeSet)
        {
            var typedNodeRow:ResultRow = nodeRow;
            
            plys.set(typedNodeRow.getVariationPath("joined_path"), typedNodeRow.getPly("ply_departure_coord", "ply_destination_coord", "ply_morph_into"));
        }

        studyInfo.plainVariation = new PlainVariation(startingSituation, plys);

        return Success(studyInfo);
    }  
}