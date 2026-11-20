local L = function() return NewbieNudge.L end

local function hunter(level)
  WOW.state.class = "HUNTER"
  WOW.state.level = level or 20
  WOW.state.itemInfo[2567] = { name = "Bow", classID = 2, subclassID = 2 }
  WOW.state.inventory[18] = { itemID = 2567 } -- ammo rules need a bow, gun or crossbow equipped
end

local function petOut()
  WOW.state.pet.exists, WOW.state.pet.hasUI, WOW.state.pet.isHunterPet = true, true, true
end

return {
  ammo_not_applicable_when_api_missing = function()
    _G.UnitUsesAmmo = nil
    load_addon(); run_checks()
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.ammo), false)
  end,
  ammo_not_applicable_for_caster = function()
    load_addon(); run_checks()
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.ammo), false)
  end,
  ammo_none = function()
    hunter(); WOW.state.usesAmmo = true; WOW.state.ammoCount = 0
    load_addon(); run_checks()
    local r = results_of("ammo")
    assert_eq(r[1].text, L().AMMO_ROW_NONE)
    assert_eq(r[1].highlight, "character")
    r[1].onClick()
    assert_eq(WOW.calls[#WOW.calls][2], "PaperDollFrame")
  end,
  ammo_low_49 = function()
    hunter(); WOW.state.usesAmmo = true; WOW.state.ammoCount = 49
    load_addon(); run_checks()
    assert_eq(results_of("ammo")[1].text, L().AMMO_ROW_LOW:format(49))
  end,
  ammo_fine_50 = function()
    hunter(); WOW.state.usesAmmo = true; WOW.state.ammoCount = 50
    load_addon(); run_checks()
    assert_eq(#results_of("ammo"), 0)
  end,
  ammo_secret_count_keeps_previous = function()
    hunter(); WOW.state.usesAmmo = true; WOW.state.ammoCount = 10
    load_addon(); run_checks()
    WOW.state.ammoCount = WOW.secret(0)
    WOW.FireEvent("UNIT_INVENTORY_CHANGED", "player"); run_checks()
    assert_eq(results_of("ammo")[1].text, L().AMMO_ROW_LOW:format(10))
  end,
  pet_not_applicable_for_mage = function()
    load_addon(); run_checks()
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.pet), false)
  end,
  pet_not_applicable_below_10 = function()
    hunter(9)
    load_addon(); run_checks()
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.pet), false)
  end,
  pet_missing_only_after_seen = function()
    hunter()
    load_addon(); run_checks()
    assert_eq(#results_of("pet"), 0, "never had a pet: nothing to say")
    petOut()
    WOW.FireEvent("UNIT_PET", "player"); run_checks()
    assert_eq(#results_of("pet"), 0)
    assert_eq(NewbieNudge.db.seen.pet, true)
    WOW.state.pet.exists = false
    WOW.FireEvent("UNIT_PET", "player"); run_checks()
    assert_eq(results_of("pet")[1].text, L().PET_ROW_MISSING)
  end,
  pet_missing_remembered_across_login = function()
    hunter()
    _G.NewbieNudgeDB = { seen = { pet = true } }
    load_addon(); run_checks()
    assert_eq(results_of("pet")[1].text, L().PET_ROW_MISSING)
  end,
  pet_missing_suppressed_when_resting_mounted_or_dead = function()
    hunter()
    _G.NewbieNudgeDB = { seen = { pet = true } }
    WOW.state.resting = true
    load_addon(); run_checks()
    assert_eq(#results_of("pet"), 0)
    WOW.state.resting = false; WOW.state.mounted = true
    WOW.FireEvent("UNIT_PET", "player"); run_checks()
    assert_eq(#results_of("pet"), 0)
    WOW.state.mounted = false; WOW.state.dead = true
    WOW.FireEvent("UNIT_PET", "player"); run_checks()
    assert_eq(#results_of("pet"), 0)
  end,
  pet_unhappy_row = function()
    hunter(); petOut(); WOW.state.pet.happiness = 2
    load_addon(); run_checks()
    local r = results_of("pet")
    assert_eq(#r, 1)
    assert_eq(r[1].text, L().PET_ROW_UNHAPPY)
    assert_nil(r[1].highlight)
  end,
  pet_happy_no_row = function()
    hunter(); petOut(); WOW.state.pet.happiness = 3
    load_addon(); run_checks()
    assert_eq(#results_of("pet"), 0)
  end,
  pet_training_points_row = function()
    hunter(); petOut(); WOW.state.pet.trainingTotal = 12; WOW.state.pet.trainingSpent = 7
    load_addon(); run_checks()
    assert_eq(results_of("pet")[1].text, L().PET_ROW_TRAINING:format(5))
  end,
  pet_table_return_shapes_handled = function()
    hunter(); petOut()
    C_PetInfo.GetPetHappiness = function() return { happiness = 1 } end
    C_PetInfo.GetPetTrainingPoints = function() return { totalPoints = 4, spent = 1 } end
    load_addon(); run_checks()
    local r = results_of("pet")
    assert_eq(r[1].text, L().PET_ROW_UNHAPPY)
    assert_eq(r[2].text, L().PET_ROW_TRAINING:format(3))
  end,
  pet_missing_api_is_silent = function()
    hunter(); petOut()
    _G.C_PetInfo = nil
    load_addon(); run_checks()
    assert_eq(#results_of("pet"), 0)
  end,
  combat_flags = function()
    load_addon()
    assert_eq(NewbieNudge.ruleByName.ammo.combat, true)
    assert_eq(NewbieNudge.ruleByName.pet.combat, true)
  end,
  -- Forever reports UnitUsesAmmo for characters with no ammo weapon; the
  -- rule must also see a bow, gun or crossbow in the ranged slot.
  ammo_requires_a_ranged_weapon_that_uses_ammo = function()
    WOW.state.class = "WARRIOR"; WOW.state.usesAmmo = true; WOW.state.ammoCount = 20
    WOW.state.itemInfo[2001] = { name = "Sword", classID = 2, subclassID = 7 }
    WOW.state.itemInfo[2002] = { name = "Bow", classID = 2, subclassID = 2 }
    WOW.state.inventory[18] = { itemID = 2001 }
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("ammo"), 0, "a sword in the ranged slot needs no ammo")
    WOW.state.inventory[18] = { itemID = 2002 }; WOW.FireEvent("PLAYER_EQUIPMENT_CHANGED", 18, true); run_checks()
    assert_eq(results_of("ammo")[1].text, NewbieNudge.L.AMMO_ROW_LOW:format(20))
    WOW.state.inventory[18] = nil; WOW.FireEvent("PLAYER_EQUIPMENT_CHANGED", 18, false); run_checks()
    assert_eq(#results_of("ammo"), 0, "nothing in the ranged slot")
  end,
}
