-- ###################单体输出####################
local Tbl = BeeUnitBuffList(tar)
local buff = BeeUnitBuffList(p)

-- 手动修改是否使用战斗状态判定,自动/半自动的区别
local combat_toggle = true -- true为自动进入战斗状态,false为手动进入战斗状态
local pvp_toggle = false -- true为PVP模式,false为PVE模式
local mount_toggle = true -- true为骑马不执行,false为骑马依然执行
local tab_toggle = false -- true为自动切换目标,false为手动tab切换目标
local key_toggle = true -- true为按下修饰键(Alt,Shift,Ctrl)时不执行,false为照常执行
local rest_toggle = true -- true为休息不执行,false为休息时依然执行
local chihe_toggle = true -- true为吃喝不执行,false为吃喝时依然执行

local isModKey = IsLeftAltKeyDown() -- 是否按下Alt键

local tar = "target" -- 目标
local p = "player" -- 自己

local p_hp_3 = 80 -- 生命值(生命分流)
local p_mana_3 = 50 -- 法力值(生命分流)
local keep_hp = 80 -- 生命吸取安全线

local auto_smfp_toggle = true -- true为智能生命分流,false为固定生命分流
local smfl_hp_cost = 0 -- 生命分流消耗法力值
local smfl_mp_get = 0 -- 生命分流获得法力值
local smfl_p_level = 0 -- 生命分流等级
local smfl_safe_hp = 50 -- 生命分流安全线
local smfl_dw = false -- 生命分流雕文是否存在

local cur_casting = BeeUnitCastSpellName(p) -- 当前施法

-- 目标存在可打断的技能
local jineng =
    "灼热烈焰,低沉咆哮,暗影烈焰,沉默,恢复,治疗结界,强效治疗结界,野性回复,恐吓尖啸,双生相协,女王之吻,治疗之环,卡兹洛加印记,地狱火,死亡凋零,暗影新星,睡眠术,低沉咆哮,暴风雪,火焰之雨,圣光术,恐惧术,生命吸取,恐惧,快速治疗,强效治疗术,治疗之触,愈合,地狱烈焰,飓风,滋养,次级治疗波,苦修,变形术,烈焰风暴" --------此为需要打断的技能
local daduan_can = BeeStringFind(jineng, BeeUnitCastSpellName(tar))
-- 目标打断技能时间
local tar_time, tar_Castingtime = BeeUnitCastSpellTime(tar)

-- 目标身上有控制BUFF，不要捣乱
local tarCtrBuff = "致盲,凿击,昏迷,变形术,闷棍,致盲,圣盾术,保护之手" -----此为判定目标身上BUFF停手
local selfCtrBuff =
    "寒冰之握,寒冰陷阱,邪恶毒气,烈焰波,低沉咆哮,上古绝望,恐慌,恐吓咆哮,蛛网喷射,蛛网爆炸,困惑,死亡缠绕,恐惧,心灵尖啸,昏迷,肾击,震荡射击,陷地,制裁之锤,深度冻结,突袭,暗影之怒,冲击波,胁迫,挤压,战争践踏,火焰冲撞,震荡波,震荡猛击,疲劳诅咒,冰冻陷阱,冰霜陷阱,冰霜新星,地缚术,断筋,蛛网,残废术,寒冰屏障,减速" ---解控
local chihe_buff = "点心,进食,喝水" -----自身有BUFF停手
local unitType = UnitCreatureType(tar)
local uTypeCheck = BeeStringFind(unitType, "亡灵,恶魔,人型生物")

-- 自己正在施法的技能，不能打断
local self_stop_castSpell =
    "钓鱼,学习,乱射,暴风雪,炉石,潜行,开启,打开,枯萎凋零,凛风冲击,寒冬号角" -----读条停手
local selfStopCastSpell = BeeUnitCastSpellName(p) == self_stop_castSpell

-- 生命分流学习等级,生命值,法力值,等级
local smfl_learn_rank, smfl_hp, smfl_mp, smfl_level = {6, 16, 26, 36, 46, 56, 68, 80},
    {27, 66, 132, 215, 306, 827, 1124, 2000}, {27, 66, 132, 215, 306, 827, 1124, 2000}, {1, 2, 3, 4, 5, 6, 7, 8}

local debug = true -- 调试模式

local function init()
    -- 人物属性
    local p_Spirit = select(2, UnitStat(p, 5)) -- 精神
    local p_Sp = GetSpellBonusDamage(6) -- 法术强度(暗影)]
    local p_level = UnitLevel(p) -- 等级

    -- 强化生命分流 天赋等级
    local smfl_rank, smfl_maxRank = BeeTalentInfo("强化生命分流")
    -- local smfl_delay                              = 3 --延迟3秒再检查,别把自己抽死了

    -- 当前生命分流等级
    local smfl_p_level = select(2, GetSpellBookItemName(select(2, GetSpellBookItemInfo("生命分流"))))

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
    -- 人物属性
    local p_Spirit = select(2, UnitStat(p, 5)) -- 精神
    local p_Sp = GetSpellBonusDamage(6) -- 法术强度(暗影)]
    local p_level = UnitLevel(p) -- 等级

    -- 还有等级加成,但是不算很多,懒得写了
    -- 生命分流消耗生命值  (基础值+精神*1.5)
    smfl_hp_cost = (smfl_hp[level] + p_Spirit * 1.5) or 0
    -- 生命分流获取法力值  (基础值+法强*0.5)*天赋等级加成
    smfl_mp_get = ((smfl_mp[level] + p_Sp * 0.5) * smfl_rank) or 0

    -- return smfl_hp_cost, smfl_mp_get
end

local function init()
    -- 强化生命分流 天赋等级
    local smfl_rank, smfl_maxRank = BeeTalentInfo("强化生命分流")

    -- 当前生命分流等级
    smfl_p_level = select(2, GetSpellBookItemName(select(2, GetSpellBookItemInfo("生命分流"))))

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

---单位存在且不是尸体还有不是玩家控制角色
local function unit_check(tar)
    local uc = UnitExists(tar) == 1 and not UnitIsDeadOrGhost(tar) and BeeUnitCanAttack(tar)

    if pvp_toggle then
        uc = uc and true -- 怪和人一起打
    else
        uc = uc and not BeeUnitPlayerControlled(tar) -- 不能是玩家控制角色
    end

    return uc
end

local function mod_check()
    local uc = true

    if combat_toggle then
        uc = uc and true -- 不管是不是战斗状态都打
    else
        uc = uc and BeeUnitAffectingCombat() -- 手动进入战斗状态
    end

    if mount_toggle then
        uc = uc and not IsMounted(p) -- 骑马时不执行
    else
        uc = uc and true
    end

    if chihe_toggle then
        uc = uc and not BeeStringFind(chihe_buff, buff) -- 吃喝时不执行
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

local function npc_check()
    local unit_flag = UnitClassification(tar) -- 返回单位分类,如精英,稀有,世界boss等
    local unit_n = "normal,trivial,minus"
    local unit_e = "rareelite,elite,rare"
    local unit_b = "worldboss"

    if UnitHealthMax(tar) <= UnitHealthMax(p) * 0.5 and UnitLevel(tar) <= UnitLevel(p) and
        BeeStringFind(unit_flag, unit_n) then
        return "杂碎"
    elseif UnitHealthMax(tar) <= UnitHealthMax(p) * 2 and UnitLevel(tar) <= UnitLevel(p) + 10 and
        BeeStringFind(unit_flag, unit_n) then
        return "小怪"
    elseif UnitHealthMax(tar) <= 4 * UnitHealthMax(p) and UnitLevel(tar) <= UnitLevel(p) + 10 and
        BeeStringFind(unit_flag, unit_e) then
        return "精英"
    elseif UnitHealthMax(tar) >= 4 * UnitHealthMax(p) and UnitLevel(tar) <= UnitLevel(p) + 10 and
        (BeeStringFind(unit_flag, unit_b) or BeeStringFind(unit_flag, unit_e)) then
        return "首领"
    end
end

-- 起手
local function spell_cast(name, delay, s_name)

    local casttime = select(7, GetSpellInfo(name)) / 1000 + delay
    local lastcast = BeeGetVariable(s_name .. "_lastcast")
    -- local lastorder = BeeGetVariable("last_order")
    if not lastcast or GetTime() - lastcast > casttime then
        BeeRun("/cast " .. name)
        BeeSetVariable(s_name .. "_lastcast", GetTime())
        -- BeeSetVariable("last_order", order)
    end
    return
end

-- 初次运行初始化
local first_init = BeeGetVariable("dt_first_init")

if not first_init then
    BeeSetVariable("dt_first_init", true)
    init()
end

-- 目标是可行的
local unit_can = unit_check(tar)

-- 选项通过监测
local mod_can = mod_check()

-- 自己解控
if BeeStringFind(selfCtrBuff, buff) then
    if BeeIsRun("/cast 自利") and BeeSpellCD("自利") == 0 then
        BeeRun("自利")
        return
    end
end

-- 插入技能则等待插入技能施放完毕
if BeeCastSpellFast() then
    return
end

-- 目标判定通过与否,未通过则选择目标并返回再次检查
if not unit_can then
    if tab_toggle then
        BeeRun("/cleartarget")
        BeeRun("/targetenemy [target=target,help][target=target,noexists][target=target,dead]")
    end
    return
end

-- 目标有控制buff，自身有吃喝等buff，自身正在施法，不要打断
if not unit_can or not mod_can or BeeStringFind(tarCtrBuff, Tbl) or selfStopCastSpell then
    return
end

-- 目标有可打断的技能，打断
if daduan_can and tar_Castingtime - tar_time > 1 and tar_time > 1 and unit_can and mod_can then
    if BeeIsRun("/cast 痛苦缠绕", tar) and BeeSpellCD("痛苦缠绕") == 0 and IsSpellInRange("痛苦缠绕", src) ==
        1 then
        BeeRun("/cast 痛苦缠绕", tar)
        return
    end
    if BeeIsRun("/cast 恐惧", tar) and BeeSpellCD("恐惧") == 0 and IsSpellInRange("恐惧", tar) == 1 and
        BeeSpellCD("痛苦缠绕") > 0 then
        BeeRun("/cast 恐惧", tar)
        return
    end
end

-- #################战斗中自动补充BUFF(生命分流)##################
-- 生命值大于生命分流安全生命值,并且有生命分流雕文,并且自身在战斗中,并且生命分流BUFF时间小于1秒,并且目标通过检测,并且附加控制项通过检测
if BeeUnitHealth(p, "%") >= p_hp_3 and BeeUnitMana(p, "%") <= p_mana_3 and smfl_dw and BeeIsRun("/cast 生命分流") and
    BeeUnitAffectingCombat() and BeePlayerBuffTime("生命分流") < 1 and unit_can and mod_can then
    if auto_smfp_toggle then
        for i = smfl_p_level, 1, -1 do
            -- 获取实时生命分流消耗生命值和获取法力值
            smfl_info(i)
            -- 如果当前生命值减去生命分流消耗生命值后仍然大于安全生命值,并且当前法力值加上生命分流获得法力值后小于法力值上限,则施放生命分流
            if BeeUnitHealth(p, "nil") - smfl_hp_cost > smfl_safe_hp / 100 * UnitHealthMax(p) and BeeUnitMana(p, "nil") +
                smfl_mp_get < UnitManaMax(p) then
                BeeRun("/cast 生命分流" .. "(等级 " .. i .. ")")
                return
            end
        end
        -- 如果智能释放失败,则强制释放等级1的生命分流获取增益
        BeeRun("/cast 生命分流" .. "(等级 1)")
        return
    end
end

-- if debug then
--     print("unit_can:" .. tostring(unit_can) .. "\rmod_can:" .. tostring(mod_can))
-- end

-- 瞬发暗影箭
if BeePlayerBuffTime("暗影冥想") > 0 and unit_can and mod_can then
    -- spell_cast("暗影箭",0.15,"ayj")
    BeeRun("/cast 暗影箭")
end

-- 起手,宝宝如果没有进入战斗状态则提前攻击目标
-- if not BeeUnitAffectingCombat("pet") and not IsPetAttackActive() and unit_can and mod_can
-- then
--     BeeRun("/petattack", tar)
-- end

-- 发现敌人斩杀线,自动吸取灵魂
if BeeUnitHealth(tar, "%") <= 25 and BeeTargetDeBuffTime("吸取灵魂") <= 4 and unit_can and mod_can then
    spell_cast("吸取灵魂", 0.2, "xqll")
    -- BeeRun("/cast 吸取灵魂")
    return
end

if unit_can and mod_can and IsSpellInRange("暗影箭") == 1 and not cur_casting then
    if BeeStringFind(npc_check(), "精英,首领,小怪") then
        -- 输出
        if not cur_casting and BeeSpellCD("暗影箭") == 0 and BeeTargetDeBuffTime("暗影之拥") < 1 and
            BeeIsRun("/cast 暗影箭") and unit_can and mod_can then
            spell_cast("暗影箭", 0.2, "ayj")
            if debug then
                print("起手暗影箭")
            end
            -- BeeRun("/cast 暗影箭")
        end
        if not cur_casting and BeeSpellCD("鬼影缠身") == 0 and BeeTargetDeBuffTime("鬼影缠身") < 2 and
            BeeIsRun("/cast 鬼影缠身") and unit_can and mod_can then
            spell_cast("鬼影缠身", 0.1, "gycs")
            -- BeeUnitCastSpellDelay("痛苦无常", 1)
            -- BeeRun("/castsequence 痛苦无常,痛苦诅咒")
        end

        if not cur_casting and BeeSpellCD("腐蚀术") == 0 and BeeTargetDeBuffTime("腐蚀术") < 3 and
            BeeIsRun("/cast 腐蚀术") and unit_can and mod_can then
            -- spell_cast("腐蚀术",0.2,"fss")
            BeeRun("腐蚀术")
        end

        if not cur_casting and BeeSpellCD("痛苦无常") == 0 and BeeTargetDeBuffTime("痛苦无常") < 4 and
            BeeIsRun("/cast 痛苦无常") and unit_can and mod_can then
            spell_cast("痛苦无常", 0.4, "tkwc")
            -- BeeUnitCastSpellDelay("痛苦无常", 1)
            -- BeeRun("/castsequence 痛苦无常,痛苦诅咒")
        end

        if not cur_casting and BeeSpellCD("痛苦诅咒") == 0 and BeeTargetDeBuffTime("痛苦诅咒") < 6 and
            BeeIsRun("/cast 痛苦诅咒") and unit_can and mod_can then
            spell_cast("痛苦诅咒", 0.2, "tkjz")
            -- BeeRun("/cast 痛苦诅咒")
        end

        if cur_casting ~= "生命吸取" and BeeSpellCD("生命吸取") == 0 and BeeTargetDeBuffTime("鬼影缠身") >=
            4 and BeeTargetDeBuffTime("痛苦无常") >= 4 and BeeTargetDeBuffTime("痛苦诅咒") >= 6 and
            BeeUnitHealth(tar, "%") > 25 and BeeIsRun("/cast 吸取生命") and BeeUnitHealth(p, "%") <= keep_hp and
            unit_can and mod_can then
            spell_cast("吸取生命", 0.2, "xqsh")
            -- BeeRun("/cast 吸取生命")
        end

        if BeeUnitHealth(p, "%") >= p_hp_3 and BeeUnitMana(p, "%") <= p_mana_3 and smfl_dw and
            BeeIsRun("/cast 生命分流") and BeeUnitAffectingCombat() and BeePlayerBuffTime("生命分流") < 1 and
            unit_can and mod_can then
            if auto_smfp_toggle then
                for i = smfl_p_level, 1, -1 do
                    -- 获取实时生命分流消耗生命值和获取法力值
                    smfl_info(i)
                    -- 如果当前生命值减去生命分流消耗生命值后仍然大于安全生命值,并且当前法力值加上生命分流获得法力值后小于法力值上限,则施放生命分流
                    if BeeUnitHealth(p, "nil") - smfl_hp_cost > smfl_safe_hp / 100 * UnitHealthMax(p) and
                        BeeUnitMana(p, "nil") + smfl_mp_get < UnitManaMax(p) then
                        BeeRun("/cast 生命分流" .. "(等级 " .. i .. ")")
                        return
                    end
                end
                -- 如果智能释放失败,则强制释放等级1的生命分流获取增益
                BeeRun("/cast 生命分流" .. "(等级 1)")
                return
            end
        end
        if not cur_casting and BeeTargetDeBuffTime("鬼影缠身") >= 4 and BeeTargetDeBuffTime("痛苦无常") >= 4 and
            BeeTargetDeBuffTime("痛苦诅咒") >= 6 and BeeUnitHealth(tar, "%") > 40 and BeeIsRun("/cast 暗影箭") and
            unit_can and mod_can then
            spell_cast("暗影箭", 0.1, "ayj")
            if debug then
                print("循环暗影箭")
            end
            -- BeeRun("/cast 暗影箭")
        end

        if BeeStringFind(npc_check(), "小怪") then
            if not cur_casting and BeeTargetDeBuffTime("鬼影缠身") >= 4 and BeeTargetDeBuffTime("痛苦无常") >= 4 and
                BeeTargetDeBuffTime("痛苦诅咒") >= 6 and BeeUnitHealth(tar, "%") > 25 and BeeUnitHealth(tar) > 800 and
                BeeIsRun("/cast 射击") and unit_can and mod_can then
                spell_cast("射击", 3, "sj")
                return
            end
        end

    elseif npc_check() == "杂碎" then
        if BeeTargetDeBuffTime("腐蚀术") < 3 and BeeIsRun("/cast 腐蚀术") and unit_can and mod_can then
            spell_cast("腐蚀术", 0.2, "fss")
        end

        if BeeTargetDeBuffTime("痛苦诅咒") < 6 and BeeIsRun("/cast 痛苦诅咒") and unit_can and mod_can then
            spell_cast("痛苦诅咒", 0.2, "tkjz")
            return
            -- BeeRun("/cast 痛苦诅咒")
        end

        if BeeTargetDeBuffTime("痛苦诅咒") >= 6 and BeeUnitHealth(tar, "%") > 25 and BeeIsRun("/cast 射击") and
            unit_can and mod_can then
            spell_cast("射击", 4, "sj")
            return
        end
    end
end
