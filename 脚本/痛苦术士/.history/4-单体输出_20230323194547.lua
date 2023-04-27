--###################单体输出####################
--插入技能
if BeeCastSpellFast() then return; end

--手动修改是否使用战斗状态判定,自动/半自动的区别
local combat_toggle                                 = true               --true为自动进入战斗状态,false为手动进入战斗状态
local pvp_toggle                                    = false              --true为PVP模式,false为PVE模式
local mount_toggle                                  = true               --true为骑马不执行,false为骑马依然执行
local tab_toggle                                    = false              --true为自动切换目标,false为手动tab切换目标
local key_toggle                                    = true               --true为按下修饰键(Alt,Shift,Ctrl)时不执行,false为照常执行

local isModKey                                      = IsLeftAltKeyDown() --是否按下Alt键

local src                                           = "target"           --目标
local p                                             = "player"           --自己

local p_hp_3                                        = 80                 --生命值(生命分流)
local p_mana_3                                      = 50                 --法力值(生命分流)
local keep_hp                                       = 80                 --生命吸取安全线

local auto_smfp_toggle                              = true               --true为智能生命分流,false为固定生命分流
local smfl_hp_cost                                  = 0                  --生命分流消耗法力值
local smfl_mp_get                                   = 0                  --生命分流获得法力值
local smfl_p_level                                  = 0                  --生命分流等级
local smfl_safe_hp                                  = 50                 --生命分流安全线
local smfl_dw                                       = false              --生命分流雕文是否存在

--生命分流学习等级,生命值,法力值,等级
local smfl_learn_rank, smfl_hp, smfl_mp, smfl_level = { 6, 16, 26, 36, 46, 56, 68, 80 },
    { 27, 66, 132, 215, 306, 827, 1124, 2000 }, { 27, 66, 132, 215, 306, 827, 1124, 2000 },
    { 1, 2, 3, 4, 5, 6, 7, 8 }


local debug = false --调试模式


local function init()
    --人物属性
    local p_Spirit                = select(2, UnitStat(p, 5)) --精神
    local p_Sp                    = GetSpellBonusDamage(6)    --法术强度(暗影)]
    local p_level                 = UnitLevel(p)              --等级

    --强化生命分流 天赋等级
    local smfl_rank, smfl_maxRank = BeeTalentInfo("强化生命分流")
    --local smfl_delay                              = 3 --延迟3秒再检查,别把自己抽死了

    --当前生命分流等级
    local smfl_p_level            = select(2,
        GetSpellBookItemName(select(2, GetSpellBookItemInfo("生命分流"))))

    for i = 1, NUM_GLYPH_SLOTS do
        local enabled, glyphType, glyphTooltipIndex, glyphSpellID, icon = GetGlyphSocketInfo(i);
        if (enabled) then
            local spell_name = GetSpellInfo(i);
            if (spell_name == "生命分流雕文") then
                smfl_dw = true
            end
        end
    end
end

local function smfl_info(level)
    --人物属性
    local p_Spirit = select(2, UnitStat(p, 5)) --精神
    local p_Sp     = GetSpellBonusDamage(6)    --法术强度(暗影)]
    local p_level  = UnitLevel(p)              --等级

    --还有等级加成,但是不算很多,懒得写了
    --生命分流消耗生命值  (基础值+精神*1.5)
    smfl_hp_cost   = (smfl_hp[level] + p_Spirit * 1.5) or 0
    --生命分流获取法力值  (基础值+法强*0.5)*天赋等级加成
    smfl_mp_get    = ((smfl_mp[level] + p_Sp * 0.5) * smfl_rank) or 0

    -- return smfl_hp_cost, smfl_mp_get
end

local function init()
    --强化生命分流 天赋等级
    local smfl_rank, smfl_maxRank = BeeTalentInfo("强化生命分流")

    --当前生命分流等级
    smfl_p_level                  = select(2,
        GetSpellBookItemName(select(2, GetSpellBookItemInfo("生命分流"))))

    for i = 1, NUM_GLYPH_SLOTS do
        local enabled, glyphType, glyphTooltipIndex, glyphSpellID, icon = GetGlyphSocketInfo(i);
        if (enabled) then
            local spell_name = GetSpellInfo(i);
            if (spell_name == "生命分流雕文") then
                smfl_dw = true
            end
        end
    end
end


--初次运行初始化
local first_init = BeeGetVariable("first_init")

if not first_init then
    BeeSetVariable("first_init", true)
    init()
end



---单位存在且不是尸体还有不是玩家控制角色
local function unit_check(src)
    local uc = UnitExists(src) == 1 and not UnitIsDeadOrGhost(src) and BeeUnitCanAttack(src)

    if pvp_toggle then
        uc = uc and true                             --怪和人一起打
    else
        uc = uc and not BeeUnitPlayerControlled(src) --不能是玩家控制角色
    end

    return uc
end

local function mod_check()
    local uc = true

    if combat_toggle then
        uc = uc and true                     --不管是不是战斗状态都打
    else
        uc = uc and BeeUnitAffectingCombat() --手动进入战斗状态
    end

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

local function npc_check()
    local unit_flag = UnitClassification(src) --返回单位分类,如精英,稀有,世界boss等
    local unit_n = "normal,trivial,minus"
    local unit_e = "rareelite,elite,rare"
    local unit_b = "worldboss"


    if UnitHealthMax(src) <= UnitHealthMax(p) * 0.5 and UnitLevel(src) <= UnitLevel(p) and BeeStringFind(unit_flag, unit_n)
    then
        return "杂碎"
    elseif UnitHealthMax(src) <= UnitHealthMax(p) * 2 and UnitLevel(src) <= UnitLevel(p) + 10 and BeeStringFind(unit_flag, unit_n)
    then
        return "小怪"
    elseif UnitHealthMax(src) <= 4 * UnitHealthMax(p) and UnitLevel(src) <= UnitLevel(p) + 10 and BeeStringFind(unit_flag, unit_e)
    then
        return "精英"
    elseif UnitHealthMax(src) >= 4 * UnitHealthMax(p) and UnitLevel(src) <= UnitLevel(p) + 10 and (BeeStringFind(unit_flag, unit_b) or BeeStringFind(unit_flag, unit_e))
    then
        return "首领"
    end
end


local unit_can = unit_check(src)

--目标判定通过与否,未通过则选择目标并返回再次检查
if not unit_can
then
    if tab_toggle then
        BeeRun("/cleartarget")
        BeeRun("/targetenemy [target=target,help][target=target,noexists][target=target,dead]")
    end
    return
end


local mod_can = mod_check()


--#################战斗中自动补充BUFF(生命分流)##################
--生命值大于生命分流安全生命值,并且有生命分流雕文,并且自身在战斗中,并且生命分流BUFF时间小于1秒,并且目标通过检测,并且附加控制项通过检测
if BeeUnitHealth(p, "%") >= p_hp_3 and smfl_dw and BeeIsRun("/cast 生命分流") and BeeUnitAffectingCombat() and BeePlayerBuffTime("生命分流") < 1 and unit_can and mod_can
then
    if auto_smfp_toggle then
        for i = smfl_p_level, 1, -1 do
            --获取实时生命分流消耗生命值和获取法力值
            smfl_info(i)
            --如果当前生命值减去生命分流消耗生命值后仍然大于安全生命值,并且当前法力值加上生命分流获得法力值后小于法力值上限,则施放生命分流
            if BeeUnitHealth(p, "nil") - smfl_hp_cost > smfl_safe_hp / 100 * UnitHealthMax(p)
                and BeeUnitMana(p, "nil") + smfl_mp_get < UnitManaMax(p)
            then
                BeeRun("/cast 生命分流" .. "(等级 " .. i .. ")")
                return
            end
        end
        --如果智能释放失败,则强制释放等级1的生命分流获取增益
        BeeRun("/cast 生命分流" .. "(等级 1)")
        return
    end
end

if debug then
    print("unit_can:" .. tostring(unit_can) .. "\rmod_can:" .. tostring(mod_can))
end

--瞬发暗影箭
if BeePlayerBuffTime("暗影冥想") > 0 and unit_can and mod_can
then
    spell_cast("暗影箭",0.15,"ayj")
    -- BeeRun("/cast 暗影箭")
    return
end


--起手,宝宝如果没有进入战斗状态则提前攻击目标
-- if not BeeUnitAffectingCombat("pet") and not IsPetAttackActive() and unit_can and mod_can
-- then
--     BeeRun("/petattack", src)
-- end

--起手
local spell_cast(name,delay,s_name)

    local casttime = select(7, GetSpellInfo(name)) / 1000 + delay
    local lastcast = BeeGetVariable(s_name.."_lastcast")
    -- local lastorder = BeeGetVariable("last_order")
    if not lastcast or GetTime() - lastcast > casttime
    then
        BeeRun("/cast " .. name)
        BeeSetVariable(s_name.."_lastcast", GetTime())
        -- BeeSetVariable("last_order", order)
    end
    return
end


if BeeTargetDeBuffTime("腐蚀术") < 1 and unit_can and mod_can
then
    spell_cast("腐蚀术",0.2,"fss")
    return
end

--发现敌人斩杀线,自动吸取灵魂
if BeeUnitHealth(src, "%") <= 25 and BeeTargetDeBuffTime("吸取灵魂") <= 4 and unit_can and mod_can
then
    spell_cast("吸取灵魂",0.2,"xqll")
    -- BeeRun("/cast 吸取灵魂")
    return
end

if unit_can and mod_can and IsSpellInRange("暗影箭") == 1 then
    if BeeStringFind(npc_check(), "精英,首领") then
        --输出

        if BeeTargetDeBuffTime("痛苦无常") < 4 and unit_can and mod_can
        then
            spell_cast("痛苦无常",0.2,"tkwc")
            -- BeeRun("/castsequence 痛苦无常,痛苦诅咒")
        end

        if BeeTargetDeBuffTime("痛苦无常") >= 4 and BeeTargetDeBuffTime("痛苦诅咒") < 6 and unit_can and mod_can
        then
            BeeRun("/cast 痛苦诅咒")
        end

        if BeeTargetDeBuffTime("痛苦无常") >= 4 and BeeTargetDeBuffTime("痛苦诅咒") >= 6 and BeeUnitHealth(src, "%") > 25 and unit_can and mod_can
        then
            BeeRun("/cast 暗影箭")
            return
        end
    elseif npc_check() == "小怪" then
        --输出
        if BeeUnitHealth(p, "%") >= p_hp_3 and BeeUnitMana(p, "%") <= p_mana_3 and BeeIsRun("/cast 生命分流") and unit_can and mod_can
        then
            BeeRun("/cast 生命分流")
            -- BeeUnitCastSpellDelay("生命分流", smfl_delay) --延迟3秒再检查,别把自己抽死了
        end

        if BeeTargetDeBuffTime("痛苦无常") < 4 and unit_can and mod_can
        then
            BeeUnitCastSpellDelay("痛苦无常", 1)
            BeeRun("/castsequence 痛苦无常,痛苦诅咒")
        end

        if BeeTargetDeBuffTime("痛苦无常") >= 4 and BeeTargetDeBuffTime("痛苦诅咒") < 6 and unit_can and mod_can
        then
            BeeRun("/cast 痛苦诅咒")
        end

        if BeeTargetDeBuffTime("痛苦无常") >= 4 and BeeTargetDeBuffTime("痛苦诅咒") >= 6 and BeeUnitHealth(src, "%") > 40 and BeeUnitHealth(src) > 1500 and BeeIsRun("/cast 暗影箭") and unit_can and mod_can
        then
            BeeRun("/cast 暗影箭")
            return
        end

        if BeeTargetDeBuffTime("痛苦无常") >= 4 and BeeTargetDeBuffTime("痛苦诅咒") >= 6 and BeeUnitHealth(src, "%") > 25 and BeeUnitHealth(src) > 800 and BeeIsRun("/cast 吸取生命") and BeeUnitHealth(p, "%") <= keep_hp and unit_can and mod_can
        then
            BeeRun("/cast 吸取生命")
            return
        end

        -- if BeeTargetDeBuffTime("痛苦无常") >= 4 and BeeTargetDeBuffTime("痛苦诅咒") >= 6 and BeeUnitHealth(src, "%") > 25 and BeeUnitHealth(src) > 800 and BeeIsRun("/cast 射击") and unit_can and mod_can
        -- then
        --     BeeRun("/cast !射击")
        --     return
        -- end
    end
end
