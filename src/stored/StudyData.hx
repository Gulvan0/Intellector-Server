package stored;

import net.shared.StudyInfo;

class StudyData extends StudyInfo
{
    public function hasTags(tags:Array<String>)
    {
        for (tag in tags)
            if (!this.tags.contains(tag))
                return false;
        return true;
    }

    public static function fromJSON(json:Dynamic):StudyData
    {
        var data:StudyData = new StudyData();
        
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
            name: name,
            description: description,
            tags: tags,
            publicity: publicity.getName(),
            keyPositionSIP: keyPositionSIP,
            variantStr: variantStr,
        };
    }
}