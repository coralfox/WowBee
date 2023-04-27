-----------------------alt键火焰之雨-------------------------
--alt键火焰之雨
if BeeUnitCastSpellName("player") == "火焰之雨" then
    return
end

if IsLeftAltKeyDown() and BeeIsRun("/cast 火焰之雨", "nogoal") and BeePlayerBuffTime("火焰之雨") == -1 and BeeUnitAffectingCombat()
then
    CastSpellByName(tostring(GetSpellInfo("火焰之雨"), nil))
    if SpellIsTargeting() then
        CameraOrSelectOrMoveStart()
        CameraOrSelectOrMoveStop()
    end
    return
end