--#################跟随焦点##################

--插入技能
if BeeCastSpellFast() then return; end

local range_max = 30
local range_min = 20


--当焦点 超 20码 或者 没跟随目标时 运行跟随目标
if UnitName("focus") and ((BeeRange("focus") <= range_max and BeeRange("focus") >= range_min) or not BeeUnitIsFollow()) then
    FollowUnit("focus");
    return
end