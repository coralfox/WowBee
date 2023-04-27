------------------------自动开火车------------------
-- 手动修改是否使用战斗状态判定,自动/半自动的区别
local combat_toggle = true -- true为自动进入战斗状态,false为手动进入战斗状态(技能)
local pvp_toggle = false -- true为PVP模式,false为PVE模式
local mount_toggle = true -- true为骑马不执行,false为骑马依然执行
local key_toggle = false -- true为按下shift执行,false为不需要shift自动执行
local tab_toggle = false -- true为自动切换目标,false为手动tab切换目标

local src = "target" -- 目标
local debug = false -- 调试模式

local auto_smfp_toggle = true -- true为智能生命分流,false为固定生命分流
local smfl_hp_cost = 0 -- 生命分流消耗法力值
local smfl_mp_get = 0 -- 生命分流获得法力值
local smfl_p_level = 0 -- 生命分流等级
local smfl_dw = false -- 生命分流雕文是否存在

-- 生命分流学习等级,生命值,法力值,等级
local smfl_learn_rank, smfl_hp, smfl_mp, smfl_level = {6, 16, 26, 36, 46, 56, 68, 80},
    {27, 66, 132, 215, 306, 827, 1124, 2000}, {27, 66, 132, 215, 306, 827, 1124, 2000}, {1, 2, 3, 4, 5, 6, 7, 8}

-- 目标的buff
local Tbl = BeeUnitBuffList(src)

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

local function init()
    for i = 1, GetNumGlyphSockets() do
        local enabled, glyphType, glyphSpellID, icon = GetGlyphSocketInfo(i)
        if (enabled and glyphSpellID) then
            local spell_name = GetSpellInfo(glyphSpellID)
            if (spell_name == "生命分流雕文") then
                smfl_dw = true
            end
            -- print("雕文" .. i .. "：" .. spell_name)
        end
    end
end

-- 首次初始化
init()

-- 插入技能则等待插入技能施放完毕
if BeeCastSpellFast() then
    return
end

---单位存在且不是尸体还有不是玩家控制角色
local function unit_check(src)
    local uc = UnitExists(src) == 1 and not UnitIsDeadOrGhost(src) and BeeUnitCanAttack(src)

    if pvp_toggle then
        uc = uc and true -- 怪和人一起打
    else
        uc = uc and not BeeUnitPlayerControlled(src) -- 不能是玩家控制角色
    end

    -- 目标是可行的,且缺少buff
    uc = uc and (not BeeStringFind("腐蚀术", Tbl) or not BeeStringFind("痛苦诅咒", Tbl))

    -- if debug then
    --     print("目标是可行的,且缺少buff-" .. tostring(uc))
    -- end
    -- 目标是射程范围内的
    uc = uc and (IsSpellInRange("腐蚀术", src) == 1 or IsSpellInRange("痛苦诅咒", src) == 1)

    return uc
end

local function mod_check()
    local isModKey = IsShiftKeyDown() -- 是否按下Shift键
    local uc = true

    if combat_toggle then
        uc = uc and true -- 不管是不是战斗状态都打
    else
        uc = uc and BeeUnitAffectingCombat() -- 手动进入战斗状态
    end

    if mount_toggle then
        uc = uc and not IsMounted("player") -- 骑马时不执行
    else
        uc = uc and true
    end

    if key_toggle then
        uc = uc and isModKey -- 按下Shift键时执行
    else
        uc = uc and true -- 不检测shift键
    end

    return uc
end

local unit_can = unit_check(src)

-- 目标判定通过与否,未通过则选择目标并返回再次检查
if not unit_can then
    if tab_toggle then
        BeeRun("/cleartarget")
        BeeRun("/targetenemy [target=target,help][target=target,noexists][target=target,dead]")
    end
    return
end

-- 附加开关通过与否
local mod_can = mod_check()

-- #################战斗中自动补充法力(生命分流)##################
local p_hp_3 = 50 -- 生命值
local p_mana_3 = 70 -- 法力值
local smfl_delay = 3 -- 延迟3秒再检查,别把自己抽死了

if BeeUnitHealth("player", "%") >= p_hp_3 and BeeUnitMana("player", "%") <= p_mana_3 and BeeIsRun("/cast 生命分流") and
    unit_can and mod_can then

    local xmfl_spell = "生命分流"
    local random_delay = 0.21

    local xmfl_casttime = select(7, GetSpellInfo(xmfl_spell)) / 1000 + random_delay
    local xmfl_lastcast = BeeGetVariable("xmfl_lastcast")
    if not xmfl_lastcast or GetTime() - xmfl_lastcast > xmfl_casttime then
        BeeRun("/cast " .. xmfl_spell)
        BeeSetVariable("xmfl_lastcast", GetTime())
    end
    return

    -- BeeRun("/cast 生命分流")
    -- BeeUnitCastSpellDelay("生命分流", smfl_delay, "player")
end

-- 再次检查,不可行则返回
if not unit_can or not mod_can then
    return
end

-- 释放腐蚀术
if BeeIsRun("/cast 腐蚀术", src) and IsSpellInRange("腐蚀术", src) == 1 and not BeeStringFind("腐蚀术", Tbl) and
    mod_can then
    BeeRun("/cast 腐蚀术", src)
end

-- 释放痛苦诅咒
if BeeIsRun("/cast 痛苦诅咒", src) and IsSpellInRange("痛苦诅咒", src) == 1 and
    not BeeStringFind("痛苦诅咒", Tbl) and mod_can then
    BeeRun("/cast 痛苦诅咒", src)
end
