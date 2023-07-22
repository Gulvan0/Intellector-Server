package database.endpoints;

import database.special_values.Timestamp;
import net.shared.dataobj.StudyInfo;

class Study 
{
    public static function create(database:Database, info:StudyInfo)
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

        var result:QueryExecutionResult = database.insertRow("study.study", studyRow, true);

        var studyID:Int = result.lastID;

        database.insertRows("study.study_tag", info.tags.map(tag -> [studyID, tag]), false);

        var variationRows:Array<Array<Dynamic>> = [];

        for (joinedPath => ply in info.plainVariation.getPlys().asStringMap().keyValueIterator())
            variationRows.push([studyID, joinedPath, ply.from.toScalarCoord(), ply.to.toScalarCoord(), ply.morphInto]);

        database.insertRows("study.variation_node", variationRows, false);

        Logger.serviceLog("e:Study.create()", 'Study created (ID = $studyID)');

        return studyID;
    }

    //TODO: Split and move
    /*public static function create(author:UserSession, info:StudyInfo) 
    {
        ...
        author.emit(StudyCreated(lastStudyID, info));
    }

    public static function overwrite(author:UserSession, id:Int, info:StudyInfo) 
    {
        var data:StudyData = Storage.getStudyData(id);

        if (data.isAuthor(author.login))
        {
            Storage.saveStudyData(id, StudyData.fromStudyInfo(author.login, info));
            Logger.serviceLog(serviceName, 'Study overwritten (ID = $id; requested by $author)');
        }
        else
            Logger.logError('$author attempted to overwrite a study (ID = $id), but its author (${data.getAuthor()}) is different');
    }

    public static function delete(author:UserSession, id:Int) 
    {
        author.storedData.removeStudy(id); //Here, we just make the study inaccessible, but not delete its data completely. Just in case
        Logger.serviceLog(serviceName, 'Study detached (ID = $id; requested by $author)');
    }

    public static function get(author:UserSession, id:Int)
    {
        var data = Storage.getStudyData(id);
        if (data == null)
            author.emit(StudyNotFound);
        else
            author.emit(SingleStudy(data.toStudyInfo(), data.getAuthor()));
    }*/    
}