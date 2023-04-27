-- #################自动补BUFF##################
-- 插入技能
if BeeCastSpellFast() then
    return;
end

local mount_toggle = true -- true为骑马不执行,false为骑马依然执行
local key_toggle = true -- true为按下修饰键(Alt,Shift,Ctrl)时不执行,false为照常执行
local chihe_toggle = true -- true为吃喝时不执行,false为吃喝时依然执行

local p_mana = 20 -- 法力值(魔甲术)
local p_mana_2 = 60 -- 法力值(生命分流)
local p_hp_2 = 85 -- 生命值(生命分流)

local isModKey = IsLeftAltKeyDown() -- 是否按下Alt键

-- local src          = "target"
local p = "player"

local auto_smfp_toggle = true -- true为智能生命分流,false为固定生命分流
local smfl_hp_cost = 0 -- 生命分流消耗法力值
local smfl_mp_get = 0 -- 生命分流获得法力值
local smfl_p_level = 0 -- 生命分流等级
local smfl_safe_hp = 40 -- 生命分流安全线
local smfl_dw = false -- 生命分流雕文是否存在

-- 生命分流学习等级,生命值,法力值,等级
local smfl_learn_rank, smfl_hp, smfl_mp, smfl_level = {6, 16, 26, 36, 46, 56, 68, 80},
    {27, 66, 132, 215, 306, 827, 1124, 2000}, {27, 66, 132, 215, 306, 827, 1124, 2000}, {1, 2, 3, 4, 5, 6, 7, 8}

local function smfl_info(level)
    -- 人物属性
    local p_Spirit = select(2, UnitStat(p, 5)) -- 精神
    local p_Sp = GetSpellBonusDamage(6) -- 法术强度(暗影)]
    local p_level = UnitLevel(p) -- 等级

    -- 强化生命分流 天赋等级
    _, _, _, _, smfl_rank, smfl_maxRank = GetTalentInfo(1, 6)

    -- print("法术强度(暗影):" .. p_Sp)
    -- 还有等级加成,但是不算很多,懒得写了
    -- 生命分流消耗生命值  (基础值+精神*1.5)
    smfl_hp_cost = (smfl_hp[level] + p_Spirit * 1.5) or 0
    -- 生命分流获取法力值  (基础值+法强*0.5)*天赋等级加成
    smfl_mp_get = ((smfl_mp[level] + p_Sp * 0.5) * (1 + 0.1 * smfl_rank)) or 0

    -- return smfl_hp_cost, smfl_mp_get
end

local function mod_check()
    local uc = true

    if mount_toggle then
        uc = uc and not IsMounted(p) -- 骑马时不执行
    else
        uc = uc and true
    end

    if key_toggle then
        uc = uc and not isModKey -- 按下Alt键时不执行
    else
        uc = uc and true
    end

    return uc
end

local function chihe_check()
    local uc = true

    if chihe_toggle then
        uc =
            uc and BeePlayerBuffTime("进食") < 1 and BeePlayerBuffTime("喝水") < 1 and BeePlayerBuffTime("点心") <
                1 -- 吃喝时不执行
    else
        uc = uc and true
    end

    return uc
end

local mod_can = mod_check() and chihe_check()

-- 当前生命分流等级
smfl_p_level = tonumber(string.sub(select(2, GetSpellName("生命分流")), -2))

if GetSpellName("邪甲术") then
 if  BeePlayerBuffTime("邪甲术") < 1 and BeeUnitMana(p, "%", 0) >= p_mana and
    BeeIsRun("/cast 邪甲术") then
    BeeRun("/cast 邪甲术")
elseif GetSpellName("魔甲术") and BeePlayerBuffTime("魔甲术") < 1 and BeeUnitMana(p, "%", 0) >= p_mana and
    BeeIsRun("/cast 魔甲术") then
    BeeRun("/cast 魔甲术")
elseif GetSpellName("恶魔皮肤") and BeePlayerBuffTime("恶魔皮肤") < 1 and BeeUnitMana(p, "%", 0) >= p_mana and
    BeeIsRun("/cast 恶魔皮肤") then
    BeeRun("/cast 恶魔皮肤")
end

if BeePlayerBuffTime("邪甲术") < 1 and BeeUnitMana(p, "%", 0) >= p_mana and BeeIsRun("/cast 邪甲术") and mod_can then

    BeeRun("/cast 邪甲术")
    return
end
-- #################自动回蓝(生命分流)##################
-- 不在战斗状态则自动回蓝
if BeeUnitHealth(p, "%") >= p_hp_2 and BeeUnitMana(p, "%") <= p_mana_2 and BeeIsRun("/cast 生命分流") and
    not BeeUnitAffectingCombat() and mod_can then
    if auto_smfp_toggle then

        -- 当前生命分流等级
        smfl_p_level = tonumber(string.sub(select(2, GetSpellName("生命分流")), -2))

        for i = smfl_p_level, 1, -1 do
            -- 获取实时生命分流消耗生命值和获取法力值
            smfl_info(i)
            -- print(smfl_hp_cost, smfl_mp_get)
            -- 如果当前生命值减去生命分流消耗生命值后仍然大于安全生命值,并且当前法力值加上生命分流获得法力值后小于法力值上限,则施放生命分流
            if BeeUnitHealth(p, "nil") - smfl_hp_cost > smfl_safe_hp / 100 * UnitHealthMax(p) and BeeUnitMana(p, "nil") +
                smfl_mp_get < UnitManaMax(p) then
                BeeRun("/cast 生命分流" .. "(等级 " .. i .. ")")
                return
            end
        end
    else
        BeeRun("/cast 生命分流")
        return
    end
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
