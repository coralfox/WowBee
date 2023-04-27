if BeeUnitCastSpellTime("player") > 0 then
    return
end

local dis_rarity = "2" -- 0-7  0=灰色 1=白色 2=绿色 3=蓝色 4=紫色 5=橙色 6=金色 7=神器
local dis_type = {3} -- 0=全部 1=装备 2=武器 3=护甲 4=消耗品 5=容器 6=宝石 7=材料 8=商业技能 9=任务 10=钥匙 11=永久 12=杂项 13=其它 14=弹药 15=箭矢 16=投掷武器
local dis_subtype = {1} -- 0=全部 1=布甲 2=皮甲 3=锁甲 4=板甲 5=披风 6=单手斧 7=双手斧 8=弓 9=枪 10=单手锤 11=双手锤 12=法杖 13=单手剑 14=双手剑 15=战斧 16=战锤 17=法术剑 18=拳套 19=杖 20=匕首 21=远程武器 22=魔杖 23=鱼竿

local s_name = "dis"
local reset_time = 10

local black_list = {}

local dic_type = {
    [0] = "全部",
    [1] = "装备",
    [2] = "武器",
    [3] = "护甲",
    [4] = "消耗品",
    [5] = "容器",
    [6] = "宝石",
    [7] = "材料",
    [8] = "商业技能",
    [9] = "任务",
    [10] = "钥匙",
    [11] = "永久",
    [12] = "杂项",
    [13] = "其它",
    [14] = "弹药",
    [15] = "箭矢",
    [16] = "投掷武器"
}

local dic_subtype = {
    [0] = "全部",
    [1] = "布甲",
    [2] = "皮甲",
    [3] = "锁甲",
    [4] = "板甲",
    [5] = "披风",
    [6] = "单手斧",
    [7] = "双手斧",
    [8] = "弓",
    [9] = "枪",
    [10] = "单手锤",
    [11] = "双手锤",
    [12] = "法杖",
    [13] = "单手剑",
    [14] = "双手剑",
    [15] = "战斧",
    [16] = "战锤",
    [17] = "法术剑",
    [18] = "拳套",
    [19] = "杖",
    [20] = "匕首",
    [21] = "远程武器",
    [22] = "魔杖",
    [23] = "鱼竿"
}

local table_type = ""
for key, value in ipairs(dis_type) do
    table_type = table_type .. dic_type[value] .. ","
end

local table_subtype = ""
for key, value in ipairs(dis_subtype) do
    table_subtype = table_subtype .. dic_subtype[value] .. ","
end

-- 上次运行时间,如果是首次运行,则设置为当前时间,并且设置index为1,或者如果当前时间与上次运行时间大于reset_time,则设置index为1
local lastcast = BeeGetVariable(s_name .. "_lastcast")
if not lastcast or GetTime() - lastcast > reset_time then
    BeeSetVariable(s_name .. "_lastcast", GetTime())
    BeeSetVariable("dis_index", 1)
elseif GetTime() - lastcast <= 5 and GetTime() - lastcast >= 1 then
    if BeeUnitCastSpellName("player") == "分解" then
        return
    end
else
    return
end

local index = BeeGetVariable("dis_index") or 1

if index <= 110 then
    local i_bag, i_slot = math.floor(index / 23), index % 23
    i_link = GetContainerItemLink(i_bag, i_slot)

    if i_link then

        i_info = {GetItemInfo(i_link)}
        -- print("分析:第" .. i_bag .. "包,第" .. i_slot .. "格的" .. i_info[1])
        if string.find(dis_rarity, i_info[3]) and (not dis_subtupe or string.find(table_subtype, i_info[7])) and
            (not dis_type or string.find(table_type, i_info[6])) then
            BeeRun("/cast 分解");
            UseContainerItem(i_bag, i_slot)
            print("正在分解:第" .. index .. "格的" .. i_info[1])
            BeeSetVariable(s_name .. "_lastcast", GetTime())
        end
    end
    index = index + 1
    BeeSetVariable("dis_index", index)
else
    BeeSetVariable("dis_index", 1)
end

