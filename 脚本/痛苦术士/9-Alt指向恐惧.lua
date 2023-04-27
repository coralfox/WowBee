-- 插入技能
if BeeCastSpellFast() then
    return;
end

------------------------自动开火车------------------
-- 手动修改是否使用战斗状态判定,自动/半自动的区别
local combat_toggle = BeeGetVariable("combat_toggle") or true -- true为自身自动进入战斗状态,false为手动进入战斗状态后再自动执行
local tar_combat_toggle = BeeGetVariable("tar_combat_toggle") or false -- true为目标进入战斗状态则自动攻击,false为不管敌方是否进入战斗状态
local pvp_toggle = BeeGetVariable("pvp_toggle") or false -- true为PVP模式,false为PVE模式
local mount_toggle = BeeGetVariable("mount_toggle") or true -- true为骑马不执行,false为骑马依然执行
local tab_toggle = BeeGetVariable("tab_toggle") or false -- true为自动切换目标,false为手动tab切换目标
local chihe_toggle = BeeGetVariable("chihe_toggle") or true -- true为吃喝不执行,false为吃喝时依然执行

local tar = "mouseover" -- 目标
local p = "player" -- 自己

-- local p_hp_3 = 80 -- 生命值(生命分流)
local chihe_buff = "点心,进食,喝水" -----自身有BUFF停手

local debug = false -- 调试模式

-- local src = "mouseover" ---[color=#ff0000]赋予鼠标指向变量为d[/color]
local tbl = BeeUnitBuffList(tar) -- 目标buff列表
local buff = BeeUnitBuffList(p) -- 自身buff列表
local m_spell = "恐惧"

-----------以上是赋予变量-----------------------------

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
        uc = uc and not IsMounted(p) and not IsFlying(p) -- 骑马/飞行时不执行
    else
        uc = uc and true
    end

    if chihe_toggle then
        uc = uc and not BeeStringFind(chihe_buff, buff) -- 吃喝时不执行
    else
        uc = uc and true
    end

    return uc
end

local function spell_casting(unit)
    if not UnitExists(unit) then
        return false
    end
    if not unit then
        unit = "target"
    end
    local castName, _, _, _, startTime, endTime = UnitCastingInfo(unit)
    if debug then
        print(castName, startTime, endTime)
    end

    if castName then
        -- 技能读条时间
        local castTime = (endTime - startTime) / 1000
        -- 已经读条时间
        local castingTime = (GetTime() * 1000 - startTime) / 1000
        -- 剩余读条时间
        local castLeft = (endTime - GetTime() * 1000) / 1000
        return castName, castTime, castingTime, castLeft
    else
        return false
    end
end

-- 技能释放
local function spell_cast(name, delay, s_name)
    local cur_castName = spell_casting(p)

    local casttime = select(7, GetSpellInfo(name)) / 1000 + delay
    local lastcast = BeeGetVariable(s_name .. "_lastcast")
    if not lastcast or GetTime() - lastcast > casttime or
        (GetTime() - lastcast < casttime / 3 and casttime > 1 and cur_castname ~= name) then
        BeeRun("/cast " .. name, tar)
        BeeSetVariable(s_name .. "_lastcast", GetTime())
        -- 将上次施法加入到变量中
        BeeSetVariable("spell_lastcast", name)
        -- BeeSetVariable("last_order", order)
    end
    return
end

-- 目标检测
local unit_can = unit_check(tar)

-- 附加开关通过与否
local mod_can = mod_check()

-- 鼠标指向偷窃
if IsLeftAltKeyDown()  then
    -- spell_cast(m_spell, 1.7, "kj")
    local cur_castName = spell_casting(p)

    if cur_castname ~= "恐惧" then
        if debug then
            print("恐惧-打断释放" .. cur_castname or false)
        end
        SpellStopTargeting() -- 停止瞄准
        SpellStopCasting() -- 停止施法
        spell_cast("恐惧", 1.7, "kj")
    end
end
