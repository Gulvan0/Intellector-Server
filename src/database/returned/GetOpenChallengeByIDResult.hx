package database.returned;

import net.shared.dataobj.GameModelData;
import net.shared.dataobj.ChallengeData;

enum GetOpenChallengeByIDResult 
{
    Active(data:ChallengeData);
    Cancelled;
    AlreadyAccepted(data:GameModelData);
    Nonexistent;
}