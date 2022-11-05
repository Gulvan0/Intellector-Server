package stored;

import net.shared.StudyInfo;

class StudyData extends StudyInfo
{
    private var author:String;

    public function getAuthor():String
    {
        return author;
    }

    public function isAuthor(login:String) 
    {
        return author == login;    
    }

    public function hasTags(tags:Array<String>)
    {
        for (tag in tags)
            if (!this.tags.contains(tag))
                return false;
        return true;
    }

    public static function fromStudyInfo(authorLogin:String, info:StudyInfo):StudyData 
    {
        var data:StudyData = new StudyData();
        
        data.author = authorLogin;
        data.name = info.name;
        data.description = info.description;
        data.tags = info.tags;
        data.publicity = info.publicity;
        data.keyPositionSIP = info.keyPositionSIP;
        data.variantStr = info.variantStr;
        
        return data;
    }

    public function toStudyInfo():StudyInfo
    {
        var info:StudyInfo = new StudyInfo();
        
        info.name = name;
        info.description = description;
        info.tags = tags;
        info.publicity = publicity;
        info.keyPositionSIP = keyPositionSIP;
        info.variantStr = variantStr;
        
        return info;
    }

    public static function fromJSON(json:Dynamic):StudyData
    {
        var data:StudyData = new StudyData();
        
        data.author = json.author;
        data.name = json.name;
        data.description = json.description;
        data.tags = json.tags;
        data.publicity = StudyPublicity.createByName(json.publicity);
        data.keyPositionSIP = json.keyPositionSIP;
        data.variantStr = json.variantStr;
        
        return data;
    }

    public function toJSON():Dynamic
    {
        return {
            author: author,
            name: name,
            description: description,
            tags: tags,
            publicity: publicity.getName(),
            keyPositionSIP: keyPositionSIP,
            variantStr: variantStr,
        };
    }
}