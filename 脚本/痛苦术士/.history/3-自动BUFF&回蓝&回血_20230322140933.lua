--#################自动补BUFF##################
--插入技能
if BeeCastSpellFast() then return; end

local mount_toggle = true               --true为骑马不执行,false为骑马依然执行
local key_toggle   = true               --true为按下修饰键(Alt,Shift,Ctrl)时不执行,false为照常执行
local chihe_toggle = true               --true为吃喝时不执行,false为吃喝时依然执行

local p_mana       = 20                 --法力值(魔甲术)
local p_mana_2     = 70                 --法力值(生命分流)
local p_hp_2       = 70                 --生命值(生命分流)

local isModKey     = IsLeftAltKeyDown() --是否按下Alt键

-- local src          = "target"
local p            = "player"

local function mod_check()
    local uc = true

    if mount_toggle then
        uc = uc and not IsMounted(p) --骑马时不执行
    else
        uc = uc and true
    end

    if key_toggle then
        uc = uc and not isModKey --按下Alt键时不执行
    else
        uc = uc and true
    end

    return uc
end

local function chihe_check()
    local uc = true

    if chihe_toggle then
        uc = uc and BeePlayerBuffTime("进食") < 1 and BeePlayerBuffTime("喝水") < 1 and
            BeePlayerBuffTime("点心") < 1 --吃喝时不执行
    else
        uc = uc and true
    end

    return uc
end

local mod_can = mod_check() and chihe_check()

if BeePlayerBuffTime("魔甲术") < 1 and BeeUnitMana(p, "%", 0) >= p_mana and BeeIsRun("/cast 魔甲术") and mod_can
then
    BeeRun("/cast 魔甲术")
    return
end
--#################自动回蓝(生命分流)##################
--不在战斗状态则自动回蓝

if BeeUnitMana(p, "%") <= p_mana_2 and BeeUnitHealth(p, "%") >= p_hp_2 and BeeIsRun("/cast 生命分流") and not BeeUnitAffectingCombat() and mod_can
then
    BeeRun("/cast 生命分流")
    return
end
--[[
local p_mana = 20 --法力值

if BeePlayerBuffTime("邪甲术")<1 and BeeUnitMana(p,"%",0)>=p_mana and BeeIsRun("/cast 邪甲术") then
    BeeRun("/cast 邪甲术")
elseif BeePlayerBuffTime("魔甲术")<1 and BeeUnitMana(p,"%",0)>=p_mana and BeeIsRun("/cast 魔甲术") then
    BeeRun("/cast 魔甲术")
elseif  BeePlayerBuffTime("恶魔皮肤")<1 and BeeUnitMana(p,"%",0)>=p_mana and BeeIsRun("/cast 恶魔皮肤") then
    BeeRun("/cast 恶魔皮肤")
end
]]
