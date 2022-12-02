package services;

import stored.PlayerData;
import entities.UserSession;
import stored.StudyData;
import net.shared.dataobj.StudyInfo;

class StudyManager 
{
    private static inline final serviceName:String = "STUDIES";
    private static var lastStudyID:Int = Storage.getServerDataField("lastStudyID");

    public static function create(author:UserSession, info:StudyInfo) 
    {
        lastStudyID++;
        Storage.setServerDataField("lastStudyID", lastStudyID);

        var data:StudyData = StudyData.fromStudyInfo(author.login, info);
        var playerData:PlayerData = Storage.loadPlayerData(author.login);

        Storage.saveStudyData(lastStudyID, data);
        playerData.addStudy(lastStudyID);
        author.emit(StudyCreated(lastStudyID, info));
        Logger.serviceLog(serviceName, 'Study created (ID = $lastStudyID) by ${author.getLogReference()}');
    }

    public static function overwrite(author:UserSession, id:Int, info:StudyInfo) 
    {
        var data:StudyData = Storage.getStudyData(id);

        if (data.isAuthor(author.login))
        {
            Storage.saveStudyData(lastStudyID, StudyData.fromStudyInfo(author.login, info));
            Logger.serviceLog(serviceName, 'Study overwritten (ID = $lastStudyID; requested by ${author.getLogReference()})');
        }
        else
            Logger.logError('${author.getLogReference()} attempted to overwrite a study (ID = $lastStudyID), but its author (${data.getAuthor()}) is different');
    }

    public static function delete(author:UserSession, id:Int) 
    {
        author.storedData.removeStudy(id); //Here, we just make the study inaccessible, but not delete its data completely. Just in case
        Logger.serviceLog(serviceName, 'Study detached (ID = $lastStudyID; requested by ${author.getLogReference()})');
    }

    public static function get(author:UserSession, id:Int)
    {
        var info = Storage.getStudyData(id);
        if (info == null)
            author.emit(StudyNotFound);
        else
            author.emit(SingleStudy(info));
    }
}