-- 插入技能
if BeeCastSpellFast() then
    return;
end
------------------------自动开火车------------------
-- 手动修改是否使用战斗状态判定,自动/半自动的区别
local combat_toggle = true -- true为自动进入战斗状态,false为手动进入战斗状态(技能)
local pvp_toggle = false -- true为PVP模式,false为PVE模式
local mount_toggle = true -- true为骑马/飞行不执行,false为骑马/飞行依然执行
local key_toggle = false -- true为按下shift执行,false为不需要shift自动执行
local tab_toggle = true -- true为自动切换目标,false为手动tab切换目标

local tar = "target" -- 目标
local p = "player" -- 自己

-- local p_hp_3 = 80 -- 生命值(生命分流)

local debug = false -- 调试模式

local tab_delay = 0.1 -- tab延迟
local tab_max = 1 -- tab最大延迟
local server_delay = 0.1 -- 服务器延迟

local auto_smfp_toggle = true -- true为智能生命分流,false为固定生命分流
local smfl_hp_cost = 0 -- 生命分流消耗法力值
local smfl_mp_get = 0 -- 生命分流获得法力值
local smfl_p_level = 0 -- 生命分流等级
local smfl_dw = false -- 生命分流雕文是否存在
local smfl_safe_hp = 75 -- 生命分流安全线
local smfl_keep_mana = 70 -- 法力值(生命分流)

-- 生命分流学习等级,生命值,法力值,等级
local smfl_learn_rank, smfl_hp, smfl_mp, smfl_level = {6, 16, 26, 36, 46, 56, 68, 80},
    {27, 66, 132, 215, 306, 827, 1124, 2000}, {27, 66, 132, 215, 306, 827, 1124, 2000}, {1, 2, 3, 4, 5, 6, 7, 8}

-- 目标的buff
local Tbl = BeeUnitBuffList(tar)

-- 腐蚀debuff
local fs_debuff = "腐蚀之种"

-- 自身被控制
local selfCtrBuff =
    "寒冰之握,寒冰陷阱,邪恶毒气,烈焰波,低沉咆哮,上古绝望,恐慌,恐吓咆哮,蛛网喷射,蛛网爆炸,困惑,死亡缠绕,恐惧,心灵尖啸,昏迷,肾击,震荡射击,陷地,制裁之锤,深度冻结,突袭,暗影之怒,冲击波,胁迫,挤压,战争践踏,火焰冲撞,震荡波,震荡猛击,疲劳诅咒,冰冻陷阱,冰霜陷阱,冰霜新星,地缚术,断筋,蛛网,残废术,寒冰屏障,减速" ---解控

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

end

local function init()
    for i = 1, GetNumGlyphSockets() do
        local enabled, glyphType, glyphSpellID, icon = GetGlyphSocketInfo(i)
        if (enabled and glyphSpellID) then
            local spell_name = GetSpellInfo(glyphSpellID)
            if (spell_name == "生命分流雕文") then
                smfl_dw = true
            end
        end
    end
end

-- 首次初始化
init()

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

local function buff_check(src)
    local bc = true
    -- 目标缺少buff
    bc = bc and not BeeStringFind(fs_debuff, Tbl or not BeeStringFind("痛苦诅咒", Tbl))

    -- 目标是射程范围内的
    bc = bc and IsSpellInRange("暗影箭", src) == 1

    return bc
end

---单位存在且不是尸体还有不是玩家控制角色
local function unit_check(src)
    local uc = UnitExists(src) == 1 and not UnitIsDeadOrGhost(src) and BeeUnitCanAttack(src)

    if pvp_toggle then
        uc = uc and true -- 怪和人一起打
    else
        uc = uc and not BeeUnitPlayerControlled(src) -- 不能是玩家控制角色
    end

    uc = uc and BeeUnitAffectingCombat(src) -- 目标在战斗状态

    return uc
end

local function mod_check()
    local isModKey = IsShiftKeyDown() -- 是否按下Shift键
    local mc = true

    if combat_toggle then
        mc = mc and true -- 不管是不是战斗状态都打
    else
        mc = mc and BeeUnitAffectingCombat() -- 手动进入战斗状态
    end

    if mount_toggle then
        mc = mc and not IsMounted(p) and not IsFlying(p) -- 骑马/飞行时不执行
    else
        mc = mc and true
    end

    if key_toggle then
        mc = mc and isModKey -- 按下Shift键时执行
    else
        mc = mc and true -- 不检测shift键
    end

    mc = mc and not UnitIsDeadOrGhost(p) -- 自身不是死亡状态或鬼魂状态

    return mc
end

-- 技能释放
local function spell_cast(name, delay, s_name)

    local casttime = select(7, GetSpellInfo(name)) / 1000 + delay
    local lastcast = BeeGetVariable(s_name .. "_lastcast")
    if not lastcast or GetTime() - lastcast > casttime then
        BeeRun("/cast " .. name)
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

-- 目标通过buff检测
local buff_can = buff_check(tar)

-- 生命值大于生命分流安全生命值,并且有生命分流雕文,并且自身在战斗中,并且生命分流BUFF时间小于1秒,并且目标通过检测,并且附加控制项通过检测
if smfl_dw and BeeIsRun("/cast 生命分流") and BeePlayerBuffTime("生命分流") < 1 and unit_can and mod_can then
    if auto_smfp_toggle then
        -- 当前生命分流等级
        smfl_p_level = tonumber(string.sub(select(2, GetSpellName("生命分流")), -2))
        for i = smfl_p_level, 1, -1 do
            -- 获取实时生命分流消耗生命值和获取法力值
            smfl_info(i)
            -- 如果当前生命值减去生命分流消耗生命值后仍然大于安全生命值,并且当前法力值加上生命分流获得法力值后小于法力值上限,则施放生命分流
            if (BeeUnitHealth(p, "nil") - smfl_hp_cost) > (smfl_safe_hp / 100 * UnitHealthMax(p)) and
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

-- #################战斗中自动补充法力(生命分流)##################

if BeeSpellCD("生命分流") == 0 and BeeUnitHealth(p, "%") >= smfl_safe_hp and BeeUnitMana(p, "%") <= smfl_keep_mana and
    BeeIsRun("/cast 生命分流") and mod_can then
    if auto_smfp_toggle then
        local smfl_flag = false
        -- 当前生命分流等级
        smfl_p_level = tonumber(string.sub(select(2, GetSpellName("生命分流")), -2))
        for i = smfl_p_level, 1, -1 do
            -- 获取实时生命分流消耗生命值和获取法力值
            smfl_info(i)
            -- 如果当前生命值减去生命分流消耗生命值后仍然大于安全生命值,并且当前法力值加上生命分流获得法力值后小于法力值上限,则施放生命分流
            if BeeUnitHealth(p, "nil") - smfl_hp_cost > smfl_safe_hp / 100 * UnitHealthMax(p) and BeeUnitMana(p, "nil") +
                smfl_mp_get < UnitManaMax(p) then
                BeeRun("/cast 生命分流" .. "(等级 " .. i .. ")")
                smfl_flag = true
                break
            end
        end
        -- -- 如果智能释放失败,则强制释放等级最高的生命分流获取增益
        -- if not smfl_flag then
        --     BeeRun("/cast 生命分流")
        -- end
    end
end

-- 瞬发暗影箭
if BeeSpellCD("暗影箭") == 0 and BeePlayerBuffTime("暗影冥思") > 0 and IsSpellInRange("暗影箭") == 1 and
    unit_can and mod_can then
    spell_cast("暗影箭", 1.2, "ayj")
    -- BeeRun("/cast 暗影箭")
end

-- 不可行则返回
if not mod_can then
    return
end

-- 目标BUFF判定通过与否,未通过则选择目标并返回再次检查
if not buff_can or not unit_can then
    if tab_toggle then
        -- local tab_time = tab_delay + server_delay
        local tab_time = BeeGetVariable("tab_time") or tab_delay + server_delay
        local lasttab = BeeGetVariable("lasttab")
        if debug then
            -- print("buff_can: " .. buff_can)
            print("tab_time: " .. tab_time)
            print("lasttab: " .. lasttab)
        end
        if not lasttab or GetTime() - lasttab > tab_time then
            -- 等待中(正常释放buff)切换目标成功,则重置延迟时间
            BeeRun("/cleartarget")
            BeeRun("/targetenemy [target=target,help][target=target,noexists][target=target,dead]")
            BeeSetVariable("lasttab", GetTime())
            BeeSetVariable("tab_time", tab_delay + server_delay)
        elseif GetTime() - lasttab < tab_time then
            -- 频繁切换则增加延迟,并放置到固定变量中
            if tab_time < tab_max then
                tab_time = tab_time + 0.1
            else
                tab_time = tab_max
            end
            BeeSetVariable("tab_time", tab_time)
        end
    end
    return
end

-- 释放
if BeeSpellCD("鬼影缠身") == 0 and BeeIsRun("/cast 鬼影缠身", tar) and IsSpellInRange("鬼影缠身", tar) == 1 and
    unit_can and mod_can then
    spell_cast("鬼影缠身", 0.3, "gycs")
    -- BeeRun("/cast 腐蚀术", src)
end
-- 释放痛苦诅咒
if BeeSpellCD("痛苦诅咒") == 0 and BeeIsRun("/cast 痛苦诅咒", tar) and IsSpellInRange("痛苦诅咒", tar) == 1 and
    not BeeStringFind("痛苦诅咒", Tbl) and unit_can and buff_can and mod_can then
    spell_cast("痛苦诅咒", 1.1, "tkzz")
    -- BeeRun("/cast 痛苦诅咒", src)
end

-- 释放腐蚀术
if BeeSpellCD("腐蚀之种") == 0 and BeeIsRun("/cast 腐蚀之种", tar) and IsSpellInRange("腐蚀之种", tar) == 1 and
    not BeeStringFind("腐蚀之种", Tbl) and unit_can and buff_can and mod_can then

    -- 根据目标测算当前鬼影缠身的飞行时间,一般30码约等于1.5秒
    local delay = tar_range / 30 * 1.5
    -- 服务器延迟加上当前暗影箭的飞行时间
    local cur_delay = delay + server_delay

    spell_cast("腐蚀之种", cur_delay, "fszz")
    -- BeeRun("/cast 腐蚀术", src)
end

