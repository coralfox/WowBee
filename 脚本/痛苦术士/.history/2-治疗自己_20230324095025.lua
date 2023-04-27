-- #################治疗自己##################
local zls_hp = 40 -- 治疗石
local ys_hp = 20 -- 药水
local sc_hp = 50 -- 死亡缠绕
local xs_hp = 70 -- 牺牲(胖子)
-- local pet_mana = 380 --法力值数值(吞噬暗影)
local pet_hp = 65 -- 生命值(吞噬暗影)

local mount_toggle = true -- true为骑马不执行,false为骑马依然执行
local make_toggle = true -- true为自动制作,false为手动制作
local key_toggle = true -- true为按下修饰键(Alt,Shift,Ctrl)时不执行,false为照常执行
local chihe_toggle = true -- true为吃喝时不执行,false为吃喝时依然执行

local isModKey = IsLeftAltKeyDown() -- 是否按下Alt键

local src = "target"
local p = "player"

local zls_name = "特效治疗石"
local ys_name = "优质治疗药水"

local auto_smfp_toggle = true -- true为智能生命分流,false为固定生命分流
local smfl_hp_cost = 0 -- 生命分流消耗法力值
local smfl_mp_get = 0 -- 生命分流获得法力值
local smfl_p_level = 0 -- 生命分流等级
local smfl_safe_hp = 50 -- 生命分流安全线
local smfl_dw = false -- 生命分流雕文是否存在

-- 次级治疗石 250 治疗石 500 强效治疗石 800 优质治疗石 1200 特效治疗石 1800 超级治疗石 2500 符文治疗石 4500
-- 初级治疗药水 70-90 次级治疗药水 140-180 治疗药水 280-360 强效治疗药水 455-585 优质治疗药水 700-900 特效治疗药水 1050-1750
-- 超级治疗药水 1500-2500 符文治疗药水 2700-4500

local function init()
    -- 人物属性
    local p_Spirit = select(2, UnitStat(p, 5)) -- 精神
    local p_Sp = GetSpellBonusDamage(6) -- 法术强度(暗影)]
    local p_level = UnitLevel(p) -- 等级
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

if not first_init then
    BeeSetVariable("first_init", true)
    init()
end

---单位存在且不是尸体还有不是玩家控制角色
local function unit_check(src)
    local uc = UnitExists(src) == 1 and not UnitIsDeadOrGhost(src) and BeeUnitCanAttack(src)

    return uc
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

    uc = uc and not UnitIsDeadOrGhost(p) -- 死亡时不执行

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

local unit_can = unit_check(src)
local mod_can = mod_check() and chihe_check()

-- 没有治疗石时自动制作
if GetItemCount(zls_name) == 0 and make_toggle and not BeeUnitAffectingCombat() and mod_can then
    local zls_spell = "制造治疗石"
    local random_delay = 0.2

    local zls_casttime = select(7, GetSpellInfo(zls_spell)) / 1000 + random_delay
    local zls_lastcast = BeeGetVariable("zls_lastcast")
    if not zls_lastcast or GetTime() - zls_lastcast > zls_casttime then
        BeeRun("/cast " .. zls_spell)
        BeeSetVariable("zls_lastcast", GetTime())
    end
    return
end

-- 治疗石
if BeeUnitHealth(p, "%") < zls_hp and GetItemCooldown(zls_name) == 0 and BeeIsRun("/use " .. zls_name) and mod_can then
    -- local usezls_spell = "制造治疗石"
    local random_delay = 0.2

    local usezls_usetime = random_delay
    local usezls_lastuse = BeeGetVariable("usezls_lastuse")
    if not usezls_lastuse or GetTime() - usezls_lastuse > usezls_usetime then
        BeeRun("/use " .. zls_name)
        BeeSetVariable("usezls_lastuse", GetTime())
    end
    return
end

-- 药水
if BeeUnitHealth(p, "%") < ys_hp and GetItemCooldown(ys_name) == 0 and BeeIsRun("/use " .. ys_name) and mod_can then
    BeeRun("/use " .. ys_name)
    return
end

-- 死亡缠绕
if BeeUnitHealth(p, "%") < sc_hp and BeeIsRun("/cast 死亡缠绕", src) and unit_can and mod_can then
    BeeRun("/cast 死亡缠绕", src)
    return
end

-- 牺牲
if BeeUnitHealth(p, "%") < xs_hp and BeeSpellCD("牺牲") == 0 and BeeIsRun("/cast 牺牲") and BeeUnitAffectingCombat() and
    BeeTargetTargetIsPlayer() and mod_can then
    local xs_spell = "牺牲"
    local random_delay = 0.5

    local xs_casttime = select(7, GetSpellInfo(xs_spell)) / 1000 + random_delay
    local xs_lastcast = BeeGetVariable("xs_lastcast")
    if not xs_lastcast or GetTime() - xs_lastcast > xs_casttime then
        BeeRun("/cast " .. xs_spell)
        BeeSetVariable("xs_lastcast", GetTime())
    end
    return
end

-- #################自动回血(宝宝)##################
-- 不在战斗状态则自动回血
if BeeUnitMana("pet", nil) >= GetSpellPowerCost("吞噬暗影") and BeeUnitHealth("pet", "%") <= pet_hp and
    BeeIsRun("/cast 吞噬暗影", "pet") and not BeeUnitAffectingCombat("pet") and not IsMounted(p) and
    BeeSpellCD("吞噬暗影") == 0 then
    local tsay_spell = "吞噬暗影"
    local random_delay = 0.23

    local tsay_casttime = select(7, GetSpellInfo(tsay_spell)) / 1000 + random_delay
    local tsay_lastcast = BeeGetVariable("tsay_lastcast")
    if not tsay_lastcast or GetTime() - tsay_lastcast > tsay_casttime then
        BeeRun("/cast " .. tsay_spell)
        BeeSetVariable("tsay_lastcast", GetTime())
    end
    return
end
