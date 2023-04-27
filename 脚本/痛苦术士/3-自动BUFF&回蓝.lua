-- #################自动补BUFF##################
-- 插入技能
if BeeCastSpellFast() then
    return;
end
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

local p_mana = 20 -- 法力值(魔甲术)
local p_mana_2 = 60 -- 法力值(生命分流)
local p_hp_2 = 85 -- 生命值(生命分流)

local isModKey = IsLeftAltKeyDown() -- 是否按下Alt键

-- local src          = "target"
local p = "player"

local buff = BeeUnitBuffList(p)

local auto_smfp_toggle = true -- true为智能生命分流,false为固定生命分流
local smfl_hp_cost = 0 -- 生命分流消耗法力值
local smfl_mp_get = 0 -- 生命分流获得法力值
local smfl_p_level = 0 -- 生命分流等级
local smfl_safe_hp = 65 -- 生命分流安全线
local smfl_dw = false -- 生命分流雕文是否存在

local ffs_type = {"法术石", "特效法术石", "极效法术石", "特效法术石", "恶魔法术石",
                  "完美法术石"} -- 法术石类型
local ffs_name = "" -- 法术石名称
-- 必须有这个技能
if GetSpellName("制造法术石") then
    ffs_name = ffs_type[tonumber(string.sub(select(2, GetSpellName("制造法术石")), -2))]
end

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

local mod_can = mod_check()

-- 没有法术石时自动制作
if GetItemCount(ffs_name) == 0 and make_toggle and not BeeUnitAffectingCombat() and mod_can and
    BeeSpellCD("制造法术石") == 0 then
    local ffs_spell = "制造法术石"
    local random_delay = 0.5

    local ffs_casttime = select(7, GetSpellInfo(ffs_spell)) / 1000 + random_delay
    local ffs_lastcast = BeeGetVariable("ffs_lastcast")
    if not ffs_lastcast or GetTime() - ffs_lastcast > ffs_casttime then
        BeeRun("/cast " .. ffs_spell)
        BeeSetVariable("ffs_lastcast", GetTime())
    end
    return
end

-- 使用法术石
if BeeWeaponEnchantInfo(1) < 0 and GetItemCount(ffs_name) ~= 0 and GetItemCooldown(ffs_name) == 0 and
    not BeeUnitAffectingCombat() and BeeIsRun("/use " .. ffs_name) and mod_can then

    local random_delay = 0.5

    local useffs_usetime = random_delay
    local useffs_lastuse = BeeGetVariable("useffs_lastuse")
    if not useffs_lastuse or GetTime() - useffs_lastuse > useffs_usetime then
        BeeRun("/use " .. ffs_name)
        BeeRun("/use 16")
        BeeSetVariable("useffs_lastuse", GetTime())
    end
    return
end

if mod_can then
    if GetSpellName("邪甲术") then
        if BeePlayerBuffTime("邪甲术") < 1 and BeeUnitMana(p, "%", 0) >= p_mana and BeeIsRun("/cast 邪甲术") then
            BeeRun("/cast 邪甲术")
        end
    elseif GetSpellName("魔甲术") then
        if BeePlayerBuffTime("魔甲术") < 1 and BeeUnitMana(p, "%", 0) >= p_mana and BeeIsRun("/cast 魔甲术") then
            BeeRun("/cast 魔甲术")
        end
    elseif GetSpellName("恶魔皮肤") then
        if BeePlayerBuffTime("恶魔皮肤") < 1 and BeeUnitMana(p, "%", 0) >= p_mana and BeeIsRun("/cast 恶魔皮肤") then
            BeeRun("/cast 恶魔皮肤")
        end
    end
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
