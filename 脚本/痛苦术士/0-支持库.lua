--是否是团队
if GetNumRaidMembers() > 0 then
    grouptype = "raid"
else
    grouptype = "party"
end


local tar = "target"
local p = "player"

local Tbl = BeeUnitBuffList(tar)
local buff = BeeUnitBuffList(p)

--手动修改是否使用战斗状态判定,自动/半自动的区别
local init_check_time = 10 -- 初始化检测时间

local init_check = BeeGetVariable("init_check")
if not init_check or GetTime() - init_check > init_check_time then
    combat_toggle = BeeGetVariable("combat_toggle") -- true为自动进入战斗状态,false为手动进入战斗状态
    tar_combat_toggle = BeeGetVariable("tar_combat_toggle") -- true为目标是否进入战斗状态都自动攻击,false为敌方进入战斗状态才会攻击
    pvp_toggle = BeeGetVariable("pvp_toggle") -- true为敌对玩家时执行,false为敌对玩家时不执行
    mount_toggle = BeeGetVariable("mount_toggle") -- true为骑马执行,false为骑马不执行
    tab_toggle = BeeGetVariable("tab_toggle") -- true为自动切换目标,false为手动tab切换目标
    kz_toggle = BeeGetVariable("kz_toggle") -- true为近身则恐惧,false为不执行恐惧法术
    key_toggle = BeeGetVariable("key_toggle") -- true为按下修饰键(Alt,Shift,Ctrl)时才会执行,false为照常执行
    rest_toggle = BeeGetVariable("rest_toggle") -- true为休息时执行,false为休息时不执行
    chihe_toggle = BeeGetVariable("chihe_toggle") -- true为吃喝时执行,false为吃喝时不执行

    -- 腐蚀debuff
    fs_spell = BeeGetVariable("fs_spell") or "腐蚀术"
    BeeSetVariable("init_check", GetTime())

    if (combat_toggle == "nil") then
        combat_toggle = true
    end
    if (tar_combat_toggle == "nil") then
        tar_combat_toggle = false
    end
    if (pvp_toggle == "nil") then
        pvp_toggle = false
    end
    if (mount_toggle == "nil") then
        mount_toggle = false
    end
    if (tab_toggle == "nil") then
        tab_toggle = true
    end
    if (kz_toggle == "nil") then
        kz_toggle = false
    end
    if (key_toggle == "nil") then
        key_toggle = false
    end
    if (rest_toggle == "nil") then
        rest_toggle = true
    end
    if (chihe_toggle == "nil") then
        chihe_toggle = true
    end
end