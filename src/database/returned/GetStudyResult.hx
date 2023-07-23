package database.returned;

import net.shared.dataobj.StudyInfo;

enum GetStudyResult 
{
    Nonexistent;
    Unauthorized;
    Success(info:StudyInfo);  
}