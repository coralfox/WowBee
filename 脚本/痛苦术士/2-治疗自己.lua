-- #################治疗自己##################
-- 手动修改是否使用战斗状态判定,自动/半自动的区别
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

local zls_hp = 40 -- 治疗石
local ys_hp = 20 -- 药水
local sc_hp = 50 -- 死亡缠绕
local xs_hp = 70 -- 牺牲(胖子)

local tsay_get_hp = 0 -- 治疗石获取生命值
local tsay_cost_mp = 0 -- 治疗石消耗法力值

local isModKey = IsLeftAltKeyDown() -- 是否按下Alt键

local tar = "target"
local p = "player"

local Tbl = BeeUnitBuffList(tar)
local buff = BeeUnitBuffList(p)

local zls_type = {"初级治疗石", "次级治疗石", "治疗石", "强效治疗石", "特效治疗石",
                  "极效治疗石", "恶魔治疗石", "邪能治疗石"}
local ys_type = {"初级治疗药水", "褪色的治疗药水", "次级治疗药水", "治疗药水",
                 "强效治疗药水", "优质治疗药水", "特效治疗药水", "不稳定的治疗药水",
                 "超级治疗药水", "复苏治疗药水", "符文治疗药水"}
-- 初级治疗石 100 次级治疗石 275 治疗石 600 强效治疗石 800 特效治疗石 1200 极效治疗石 2080 恶魔治疗石 3500 邪能治疗石 4280
-- 初级治疗药水 70-90 次级治疗药水 140-180 治疗药水 280-360 强效治疗药水 455-585 优质治疗药水 700-900 特效治疗药水 1050-1750
-- 超级治疗药水 1500-2500 符文治疗药水 2700-4500
local tsay_hp, tsay_mp = {315, 564, 831, 1122, 1524, 1956, 2463, 3009, 3468},
    {85, 150, 215, 285, 380, 480, 595, 710, 800}

local zls_name = zls_type[tonumber(string.sub(select(2, GetSpellName("制造治疗石")), -2))]

local ys_name = BeeGetVariable("ys_name") or "超级治疗药水"

-- 吞噬暗影的判断
if GetSpellName("吞噬暗影") then

    -- tsay_get_hp = tsay_hp[tonumber(string.sub(select(2, GetSpellName("吞噬暗影")), -2))] -- 生命值(吞噬暗影)
    -- tsay_cost_mp = tsay_mp[tonumber(string.sub(select(2, GetSpellName("吞噬暗影")), -2))] -- 法力值数值(吞噬暗影)

    tsay_get_hp = tsay_hp[tonumber(string.sub(select(2, GetSpellName("吞噬暗影")), -2))] -- 生命值(吞噬暗影)
    tsay_cost_mp = select(4, GetSpellInfo(47988)) -- 法力值数值(吞噬暗影)
end

---单位存在且不是尸体还有不是玩家控制角色
local function unit_check(src)
    local uc = UnitExists(src) == 1 and not UnitIsDeadOrGhost(src) and BeeUnitCanAttack(src)

    if pvp_toggle then
        uc = uc and true -- 怪和人一起打
    else
        uc = uc and not BeeUnitPlayerControlled(tar) -- 不能是玩家控制角色
    end

    return uc
end

local function mod_check()
    local mc = true

    if mount_toggle then
        mc = mc and not IsMounted(p) and not IsFlying(p) -- 骑马/飞行时不执行
    else
        mc = mc and true
    end

    if chihe_toggle then
        mc = mc and true
    else
        mc = mc and not BeeStringFind(chihe_buff, buff) -- 吃喝时不执行
    end

    if key_toggle then
        mc = mc and isModKey -- 按下修饰键时执行
    else
        mc = mc and true -- 不检测修饰键
    end

    uc = uc and not UnitIsDeadOrGhost(p) -- 自身不是死亡状态或鬼魂状态

    return mc
end

local unit_can = unit_check(tar)
local mod_can = mod_check()

-- 没有治疗石时自动制作
if GetItemCount(zls_name) == 0 and make_toggle and not BeeUnitAffectingCombat() and mod_can and
    BeeSpellCD("制造治疗石") == 0 then
    local zls_spell = "制造治疗石"
    local random_delay = 0.5

    local zls_casttime = select(7, GetSpellInfo(zls_spell)) / 1000 + random_delay
    local zls_lastcast = BeeGetVariable("zls_lastcast")
    if not zls_lastcast or GetTime() - zls_lastcast > zls_casttime then
        BeeRun("/cast " .. zls_spell)
        BeeSetVariable("zls_lastcast", GetTime())
    end
    return
end

-- 治疗石
if BeeUnitHealth(p, "%") < zls_hp and GetItemCount(zls_name) ~= 0 and GetItemCooldown(zls_name) == 0 and
    BeeIsRun("/use " .. zls_name) and mod_can then
    -- local usezls_spell = "制造治疗石"
    local random_delay = 0.5

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
if BeeUnitHealth(p, "%") < sc_hp and BeeSpellCD("死亡缠绕") == 0 and BeeIsRun("/cast 死亡缠绕", tar) and
    unit_can and mod_can then
    BeeRun("/cast 死亡缠绕", tar)
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
if GetSpellName("吞噬暗影") and not BeeUnitCastSpellName("pet") then

    if BeeUnitMana("pet", nil) >= tsay_cost_mp and BeeUnitHealth("pet", "nil") + tsay_get_hp <= UnitHealthMax("pet") and
        BeeIsRun("/cast 吞噬暗影", "pet") and not BeeUnitAffectingCombat(p) and mod_can and
        BeeSpellCD("吞噬暗影") == 0 then
        local tsay_spell = "吞噬暗影"
        local random_delay = 0.5

        local tsay_casttime = select(7, GetSpellInfo(tsay_spell)) / 1000 + random_delay
        local tsay_lastcast = BeeGetVariable("tsay_lastcast")
        if not tsay_lastcast or GetTime() - tsay_lastcast > tsay_casttime then
            BeeRun("/cast " .. tsay_spell)
            BeeSetVariable("tsay_lastcast", GetTime())
        end
        return
    end
end
