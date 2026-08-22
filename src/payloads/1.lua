    if _G.PlayerMapMarker and type(_G.PlayerMapMarker.Stop) == "function" then
        pcall(function() _G.PlayerMapMarker.Stop() end)
        pcall(function() _G.PlayerMapMarker.ClearAllMarks() end)
        _G.PlayerMapMarker.bActive = false
    end
    if _G.RedBoxOverlay and type(_G.RedBoxOverlay.Stop) == "function" then
        pcall(function() _G.RedBoxOverlay.Stop() end)
    end
    local PlayerMapMarker = {}
    -- ============================================================
    -- SRCHUB AIMBOT V2 - ULTRA OPTIMIZED (NO LAG)
    -- ============================================================
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local GameplayStatics = import("GameplayStatics")
    local KismetSystemLibrary = import("KismetSystemLibrary")
    local KismetMathLibrary = import("KismetMathLibrary")
    local FVector2D = import("Vector2D")
    local HitResultClass = import("HitResult")
    local ui_util = require("client.common.ui_util")

    local function Valid(obj)
        if not obj then return false end
        if slua and slua.isValid then
            local ok, v = pcall(slua.isValid, obj)
            if not ok or not v then return false end
        end
        return true
    end

    _G.AimbotConfig = _G.AimbotConfig or {
        Enable = true,
        Bone = 2,              -- 1 = Ø§Ù„Ø±Ø£Ø³, 2 = Ø§Ù„ØµØ¯Ø±, 3 = Ø§Ù„Ø®ØµØ±
        Speed = 50,            -- Ø³Ø±Ø¹Ø© Ø§Ù„ØªØµÙˆÙŠØ¨ (1-100)
        FOV = 30,              -- Ù…Ø¬Ø§Ù„ Ø§Ù„Ø±Ø¤ÙŠØ© (Ø¯Ø±Ø¬Ø©)
        Distance = 250,        -- Ø§Ù„Ù…Ø³Ø§ÙØ© Ø§Ù„Ù‚ØµÙˆÙ‰ (Ù…ØªØ±)
        Smooth = true,         -- ØªÙØ¹ÙŠÙ„ Ø§Ù„ØªÙ…Ù„ÙŠØ³ (Ø§Ù„Ø³Ù„Ø§Ø³Ø©)
        VisCheck = true,       -- Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ø±Ø¤ÙŠØ©
        IgnoreKnock = false,   -- ØªØ¬Ø§Ù‡Ù„ Ø§Ù„Ù…ØµØ§Ø¨ÙŠÙ†
        IgnoreBot = false,     -- ØªØ¬Ø§Ù‡Ù„ Ø§Ù„Ø¨ÙˆØªØ§Øª
        Condition = 1,         -- 1 = Ø¹Ù†Ø¯ Ø§Ù„Ø¥Ø·Ù„Ø§Ù‚ ÙÙ‚Ø·, 2 = Ø¯Ø§Ø¦Ù…Ø§Ù‹
        RecoilComp = 0,        -- ØªØ¹ÙˆÙŠØ¶ Ø§Ù„Ø§Ø±ØªØ¯Ø§Ø¯ (0-100)
        BurstAim = false,      -- ÙˆØ¶Ø¹ Ø§Ù„Ø±Ø´Ù‚Ø©: ØªØ¹ÙˆÙŠØ¶ ØªÙ„Ù‚Ø§Ø¦ÙŠ Ø­Ø³Ø¨ Ø§Ù„Ù…Ø³Ø§ÙØ©
        Prediction = true,     -- velocity lead + bullet drop compensation
        BulletSpeed = 0,       -- 0 = auto from weapon (m/s)
    }

    -- Ø§Ù„Ø¹Ø¸Ø§Ù… Ø§Ù„Ø£Ø³Ø§Ø³ÙŠØ© ÙÙ‚Ø· Ù„ØªÙ‚Ù„ÙŠÙ„ Ø§Ù„Ø¶ØºØ· Ø¨Ø¯Ù„Ø§Ù‹ Ù…Ù† 20 Ø¹Ø¸Ù…Ø©
    local PriorityBones = { "spine_03", "head", "pelvis" }

    -- Ø¥Ø¹Ø§Ø¯Ø© Ø§Ø³ØªØ®Ø¯Ø§Ù… Ø§Ù„ÙƒØ§Ø¦Ù†Ø§Øª Ù„Ù…Ù†Ø¹ Ø¥Ø¬Ù‡Ø§Ø² Ø§Ù„Ø°Ø§ÙƒØ±Ø© (Garbage Collection Stutter)
    local ReusableStartPos = { X = 0, Y = 0, Z = 0 }
    local ReusableScreenPos = FVector2D and FVector2D() or { X = 0, Y = 0 }
    local ReuseScreenPixel = FVector2D and FVector2D() or { X = 0, Y = 0 }
    local ReuseCanvasLocal = FVector2D and FVector2D() or { X = 0, Y = 0 }
    local CachedHitResult = HitResultClass and HitResultClass() or {}

    local function IsPlayerFiring(player)
        if not Valid(player) then return false end
        if player.bIsWeaponFiring == true then return true end
        if player.WeaponManagerComponent and Valid(player.WeaponManagerComponent) and player.WeaponManagerComponent.bIsWeaponFiring == true then
            return true
        end
        
        local pc = nil
        if type(player.GetPlayerControllerSafety) == "function" then
            pc = player:GetPlayerControllerSafety()
        end
        
        return Valid(pc) and pc.bIsWeaponFiring == true
    end

    local function GetEnemyTargets(player, radius)
        local result = {}
        if not Valid(player) then return result end
        
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then
            allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then
            for _, char in pairs(GameplayData.GameCharacters) do
                table.insert(allCharacters, char)
            end
        end
        
        local myTeam = type(player.GetTeamID) == "function" and player:GetTeamID() or nil
        
        for _, actor in pairs(allCharacters) do
            if Valid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
                if actor:GetTeamID() ~= myTeam then
                    local dist = player:GetDistanceTo(actor)
                    if dist <= radius then
                        table.insert(result, actor)
                    end
                end
            end
        end
        return result
    end

    local function GetBoneLocationSafety(target, boneName)
        if not Valid(target) or not boneName then return nil end
        local pos = nil
        pcall(function()
            if type(target.GetBonePos) == "function" then
                pos = target:GetBonePos(boneName, {X=0, Y=0, Z=0})
            end
            if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    pos = target:GetSocketLocation(boneName)
                end
            end
        end)
        return pos
    end

    -- ÙØ­Øµ Ø±Ø¤ÙŠØ© Ø®ÙÙŠÙ ÙˆØ³Ø±ÙŠØ¹
    local function IsBoneVisible(pc, camLoc, target, bonePos, ignoreActors)
        if not Valid(pc) or not Valid(target) or not bonePos or not camLoc then return false end
        if not KismetSystemLibrary or not KismetSystemLibrary.LineTraceSingle then return true end

        local dx = bonePos.X - camLoc.X
        local dy = bonePos.Y - camLoc.Y
        local dz = bonePos.Z - camLoc.Z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist < 50 then return true end

        ReusableStartPos.X = camLoc.X + (dx / dist) * 60
        ReusableStartPos.Y = camLoc.Y + (dy / dist) * 60
        ReusableStartPos.Z = camLoc.Z + (dz / dist) * 60

        local bVisible = false
        pcall(function()
            local bHit = KismetSystemLibrary.LineTraceSingle(
                pc, ReusableStartPos, bonePos, 0, false, ignoreActors, 0, CachedHitResult, true
            )

            if bHit then
                local hitActor = nil
                if type(CachedHitResult.GetActor) == "function" then
                    hitActor = CachedHitResult:GetActor()
                elseif CachedHitResult.Actor then
                    hitActor = CachedHitResult.Actor
                end

                if Valid(hitActor) then
                    if hitActor == target or (type(hitActor.IsChildOf) == "function" and hitActor:IsChildOf(target)) then
                        bVisible = true
                    end
                end
            else
                bVisible = true
            end
        end)

        return bVisible
    end

    local function ProcessAimbotFrame()
        if _G.MemoryConfig then
            if _G.MemoryConfig.IpadView then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local uTPPCam = player.ThirdPersonCameraComponent
                        if Valid(uTPPCam) and not player.bIsWeaponAiming then
                            uTPPCam.FieldOfView = _G.MemoryConfig.IpadFOV or 120
                        end
                    end
                end)
                _G.MemoryConfig._IpadWasActive = true
            elseif _G.MemoryConfig._IpadWasActive then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local uTPPCam = player.ThirdPersonCameraComponent
                        if Valid(uTPPCam) and not player.bIsWeaponAiming then
                            uTPPCam.FieldOfView = 90
                        end
                    end
                end)
                _G.MemoryConfig._IpadWasActive = false
            end

            if _G.MemoryConfig.SmallCrosshair then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local weapon = nil
                        if type(player.GetCurrentShootWeapon) == "function" then 
                            weapon = player:GetCurrentShootWeapon()
                        elseif type(player.GetCurrentWeapon) == "function" then 
                            weapon = player:GetCurrentWeapon() 
                        elseif player.WeaponManagerComponent and Valid(player.WeaponManagerComponent) and type(player.WeaponManagerComponent.GetCurrentWeapon) == "function" then
                            weapon = player.WeaponManagerComponent:GetCurrentWeapon()
                        end
                        if Valid(weapon) then
                            local entity = weapon.ShootWeaponEntity or weapon.ShootWeaponEntity_GEN_VARIABLE
                            if Valid(entity) then
                                entity.GameDeviationFactor = 0.0
                            end
                        end
                    end
                end)
                _G.MemoryConfig._CrosshairWasActive = true
            elseif _G.MemoryConfig._CrosshairWasActive then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local weapon = nil
                        if type(player.GetCurrentShootWeapon) == "function" then 
                            weapon = player:GetCurrentShootWeapon()
                        elseif type(player.GetCurrentWeapon) == "function" then 
                            weapon = player:GetCurrentWeapon() 
                        elseif player.WeaponManagerComponent and Valid(player.WeaponManagerComponent) and type(player.WeaponManagerComponent.GetCurrentWeapon) == "function" then
                            weapon = player.WeaponManagerComponent:GetCurrentWeapon()
                        end
                        if Valid(weapon) then
                            local entity = weapon.ShootWeaponEntity or weapon.ShootWeaponEntity_GEN_VARIABLE
                            if Valid(entity) then
                                entity.GameDeviationFactor = 1.0
                            end
                        end
                    end
                end)
                _G.MemoryConfig._CrosshairWasActive = false
            end

            
        end

        if not _G.AimbotConfig.Enable then return end
        
        local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
        if not Valid(player) then return end
        
        local pc = type(player.GetPlayerControllerSafety) == "function" and player:GetPlayerControllerSafety() or nil
        if not Valid(pc) then return end
        
        local cond = _G.AimbotConfig.Condition or 1
        if cond == 1 and not IsPlayerFiring(player) then return end
        
        local maxDistMeters = _G.AimbotConfig.Distance or 250
        local enemies = GetEnemyTargets(player, maxDistMeters * 100)
        if not enemies or #enemies == 0 then return end
        
        local camManager = GameplayStatics.GetPlayerCameraManager(pc, 0)
        if not Valid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        local camRot = camManager:GetCameraRotation()
        if not camLoc or not camRot then return end

        local viewportSize = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize() or nil
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = ((_G.AimbotConfig.FOV or 30) / 100.0) * centerX
        
        local bestTarget = nil
        local bestTargetBonePos = nil
        local bestScore = 99999999
        
        local useVisCheck = _G.AimbotConfig.VisCheck ~= false
        local igKnock = _G.AimbotConfig.IgnoreKnock or false
        local igBot = _G.AimbotConfig.IgnoreBot or false

        local aimBoneName = PriorityBones[_G.AimbotConfig.Bone or 2] or "spine_03"

        _G._AIM_LOCKED_CHAR = nil

        -- Ù…Ø±Ø­Ù„Ø© 1: ØªØµÙÙŠØ© Ø§Ù„Ù‡Ø¯Ù Ø§Ù„Ø£Ù‚Ø±Ø¨ Ù„Ù„Ø´Ø§Ø´Ø© Ø£ÙˆÙ„Ø§Ù‹ (Ø¨Ø¯ÙˆÙ† Ø¥Ù‡Ø¯Ø§Ø± Ø§Ù„Ù…Ø¹Ø§Ù„Ø¬ ÙÙŠ LineTrace)
        for _, target in ipairs(enemies) do
            if Valid(target) then
                if igKnock and target.HealthStatus == 1 then goto continue end
                
                if igBot then
                    local tIsBot = (target.bIsAI == true or target.IsAI == true)
                    local pState = target.PlayerState
                    if Valid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                    if tIsBot then goto continue end
                end

                -- ÙØ­Øµ Ø§Ù„Ù…ÙˆÙ‚Ø¹ Ø§Ù„Ø§ÙØªØ±Ø§Ø¶ÙŠ (Ø§Ù„Ø¹Ø¸Ù… Ø§Ù„Ù…Ø®ØªØ§Ø±)
                local targetBonePos = GetBoneLocationSafety(target, aimBoneName)
                if targetBonePos and (targetBonePos.X ~= 0 or targetBonePos.Y ~= 0 or targetBonePos.Z ~= 0) then
                    local success = pc:ProjectWorldLocationToScreen(targetBonePos, ReusableScreenPos, false)
                    if success and ReusableScreenPos.X > 0 and ReusableScreenPos.Y > 0 then
                        local dx = ReusableScreenPos.X - centerX
                        local dy = ReusableScreenPos.Y - centerY
                        local distScreen = math.sqrt(dx * dx + dy * dy)

                        -- hysteresis: naya target kam az kam 12% qareeb ho tabhi switch (flip-flop anti-jitter)
                        local switchBias = (bestTarget ~= nil) and (bestScore * 0.88) or bestScore
                        if distScreen <= FOV_RADIUS and distScreen < switchBias then
                            -- Ù…Ø±Ø­Ù„Ø© 2: ÙØ­Øµ Ø§Ù„Ø±Ø¤ÙŠØ© ÙÙ‚Ø· Ù„Ù„Ù…Ø±Ø´Ø­ Ø§Ù„Ø£ÙØ¶Ù„
                            local isVisible = true
                            local validBonePos = targetBonePos
                            
                            if useVisCheck then
                                isVisible = false
                                local orderedBones = { aimBoneName }
                                for _, bn in ipairs(PriorityBones) do
                                    if bn ~= aimBoneName then orderedBones[#orderedBones + 1] = bn end
                                end
                                for _, boneName in ipairs(orderedBones) do
                                    local bPos = GetBoneLocationSafety(target, boneName)
                                    if bPos and IsBoneVisible(pc, camLoc, target, bPos) then
                                        isVisible = true
                                        validBonePos = bPos
                                        break
                                    end
                                end
                            end

                            if isVisible then
                                bestScore = distScreen
                                bestTarget = target
                                bestTargetBonePos = validBonePos
                            end
                        end
                    end
                end
            end
            ::continue::
        end
        
        if not Valid(bestTarget) or not bestTargetBonePos then return end

        _G._AIM_LOCKED_CHAR = bestTarget

        -- AIM PREDICTION: velocity lead + gravity drop (SDK-accurate)
        local bPredictOn = (_G.AimbotConfig.Prediction ~= false)
        local aimPosX, aimPosY, aimPosZ = bestTargetBonePos.X, bestTargetBonePos.Y, bestTargetBonePos.Z
        local dropPitchDeg = 0.0
        if bPredictOn then
            pcall(function()
                local target = bestTarget
                -- 1) bullet speed (cm/s): config override ya weapon se auto
                local bulletSpeed = tonumber(_G.AimbotConfig.BulletSpeed) or 0
                local gravScale = 1.0
                local noGravRange = 0.0
                local weapon = nil
                pcall(function()
                    if type(player.GetCurrentShootWeapon) == "function" then weapon = player:GetCurrentShootWeapon() end
                end)
                if Valid(weapon) then
                    if bulletSpeed < 100 then
                        pcall(function()
                            if type(weapon.GetBulletFireSpeedFromEntity) == "function" then
                                local s = weapon:GetBulletFireSpeedFromEntity()
                                if s and s > 1000 then bulletSpeed = s end
                            end
                        end)
                    end
                    pcall(function()
                        local ent = weapon.ShootWeaponEntity or weapon.ShootWeaponEntity_GEN_VARIABLE
                        if Valid(ent) then
                            if ent.LaunchGravityScale then gravScale = tonumber(ent.LaunchGravityScale) or 1.0 end
                            if ent.MaxNoGravityRange then noGravRange = tonumber(ent.MaxNoGravityRange) or 0.0 end
                        end
                    end)
                end
                if bulletSpeed < 10000 then bulletSpeed = 80000 end -- fallback ~800 m/s

                -- 2) target velocity (cm/s): movement comp -> GetVelocity -> vehicle
                local velX, velY, velZ = 0.0, 0.0, 0.0
                local mv = nil
                pcall(function() mv = target.STCharacterMovement or target.CharacterMovement end)
                local gotVel = false
                if Valid(mv) then
                    pcall(function()
                        if mv.Velocity then
                            velX = mv.Velocity.X or 0; velY = mv.Velocity.Y or 0; velZ = mv.Velocity.Z or 0
                            gotVel = true
                        end
                    end)
                end
                if not gotVel then
                    pcall(function()
                        if type(target.GetVelocity) == "function" then
                            local v = target:GetVelocity()
                            if v then velX = v.X or 0; velY = v.Y or 0; velZ = v.Z or 0; gotVel = true end
                        end
                    end)
                end
                if not gotVel or (math.abs(velX) + math.abs(velY)) < 1.0 then
                    -- vehicle case: character attached ho to vehicle velocity lo
                    pcall(function()
                        local veh = target.Vehicle or target.CurrentVehicle
                        if Valid(veh) then
                            local vv = nil
                            pcall(function() vv = veh.VehicleMovement and veh.VehicleMovement.Velocity end)
                            if not vv then pcall(function() vv = veh.GetVelocity and veh:GetVelocity() end) end
                            if vv then velX = vv.X or 0; velY = vv.Y or 0; velZ = vv.Z or 0 end
                        end
                    end)
                end

                -- 3) iterative lead: t = dist/bulletSpeed -> predict -> refine
                local cxp, cyp, czp = camLoc.X, camLoc.Y, camLoc.Z
                local px, py, pz = aimPosX, aimPosY, aimPosZ
                local flyT = 0.0
                for _ = 1, 2 do
                    local ddx, ddy, ddz = px - cxp, py - cyp, pz - czp
                    local distCm = math.sqrt(ddx * ddx + ddy * ddy + ddz * ddz)
                    flyT = distCm / bulletSpeed
                    px = aimPosX + velX * flyT
                    py = aimPosY + velY * flyT
                    pz = aimPosZ + velZ * flyT
                end

                -- 4) gravity drop: g = 980 * LaunchGravityScale, MaxNoGravityRange ke andar zero
                local g = 980.0 * gravScale
                if g > 0 and flyT > 0 then
                    local hdx, hdy = px - cxp, py - cyp
                    local horizCm = math.sqrt(hdx * hdx + hdy * hdy)
                    if horizCm > noGravRange then
                        local dropCm = 0.5 * g * flyT * flyT
                        dropPitchDeg = math.deg(math.atan(dropCm / math.max(horizCm, 1.0)))
                        pz = pz + dropCm
                    end
                end

                local NV = GetFVector(px, py, pz)
                if NV then
                    bestTargetBonePos = NV
                    aimPosX, aimPosY, aimPosZ = px, py, pz
                end
            end)
        end

        -- Ø­Ø³Ø§Ø¨ Ø§Ù„ØªÙˆØ¬ÙŠÙ‡ ÙˆØ§Ù„Ø³Ù„Ø§Ø³Ø©
        local targetRot = KismetMathLibrary.FindLookAtRotation(camLoc, bestTargetBonePos)
        if not targetRot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        
        local deltaYaw = targetRot.Yaw - camRot.Yaw
        local deltaPitch = targetRot.Pitch - camRot.Pitch
        
        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        -- ØªØ¹ÙˆÙŠØ¶ Ø§Ù„Ø³ÙƒÙˆØ¨ Ø¹Ù†Ø¯ ÙØªØ­ Ø§Ù„Ø²ÙˆÙ… (lerp-smoothed, no hard jumps)
        local currentFOV = camManager.GetFOVAngle and camManager:GetFOVAngle() or 90.0
        local wantCorr = 0.0
        if not bPredictOn and currentFOV < 65.0 then
            -- legacy zoom hack: sirf jab Prediction OFF ho (physics drop real comp karta hai)
            local zoomRatio = (65.0 - currentFOV) / 65.0
            local distMeters = player:GetDistanceTo(bestTarget) / 100.0
            if distMeters > 50 then
                wantCorr = math.min((distMeters - 50) * 0.015 * zoomRatio, 1.0)
            end
        end
        _G._AIM_ZoomCorr = (_G._AIM_ZoomCorr or 0) + (wantCorr - (_G._AIM_ZoomCorr or 0)) * 0.18
        if _G._AIM_ZoomCorr < 0.005 then _G._AIM_ZoomCorr = 0 end
        deltaPitch = deltaPitch - _G._AIM_ZoomCorr

        -- physics drop compensation: bullet girne ka angle upar add
        if dropPitchDeg > 0 then
            deltaPitch = deltaPitch + dropPitchDeg
        end

        local speedVal = _G.AimbotConfig.Speed or 50
        local finalPitch, finalYaw

        if math.abs(deltaPitch) < 0.05 and math.abs(deltaYaw) < 0.05 then
            -- deadzone: bone pe exact snap, micro-oscillation khatam
            finalPitch = currentRot.Pitch + deltaPitch
            finalYaw = currentRot.Yaw + deltaYaw
        elseif _G.AimbotConfig.Smooth ~= false then
            local smoothFactor = math.max(0.01, math.min(speedVal / 100.0, 1.0))
            finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
            finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
        else
            finalPitch = currentRot.Pitch + deltaPitch
            finalYaw = currentRot.Yaw + deltaYaw
        end

        local recoilVal = _G.AimbotConfig.RecoilComp or 0
        if _G.AimbotConfig.BurstAim then
            local burstDist = player:GetDistanceTo(bestTarget) / 100.0
            recoilVal = math.max(0.3, math.min(1, 1.2 - burstDist * 0.001))
        end
        local wantPull = 0.0
        if recoilVal > 0 and IsPlayerFiring(player) then
            wantPull = math.min((recoilVal / 100.0) * 2.2, 1.2)
        end
        -- pull bhi ramp in/out hota hai, firing start/stop pe pop nahi
        _G._AIM_Pull = (_G._AIM_Pull or 0) + (wantPull - (_G._AIM_Pull or 0)) * 0.25
        if _G._AIM_Pull < 0.01 then _G._AIM_Pull = 0 end
        if _G._AIM_Pull > 0 then
            finalPitch = finalPitch - _G._AIM_Pull
        end
        
        pc:SetControlRotation({ Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }, "SrchubAimbot")
    end


    -- ============================================================
    -- RED BOX OVERLAY - ORIGINAL DESIGN & OPTIMIZED LOGIC (FIXED)
    -- ============================================================
    local RedBoxOverlay = {
        bActive = false,
        MainContainer = nil,
        WidgetSlot = nil,
        TextBlock = nil,
        
        -- Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ù…Ø³ØªØ·ÙŠÙ„ Ø§Ù„Ø£ØµÙ„ÙŠØ©
        Width = 300,            -- Ø§Ù„Ø¹Ø±Ø¶ Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø£ØµÙ„ÙŠ
        Height = 28,           -- Ø§Ù„Ø§Ø±ØªÙØ§Ø¹ Ø§Ù„Ø£ØµÙ„ÙŠ
        OffsetY = 10,          -- Ø§Ù„Ù…Ø³Ø§ÙØ©
        
        -- Ø£Ø¹Ø¯Ø§Ø¯ Ø§Ù„Ù„Ø§Ø¹Ø¨ÙŠÙ† ÙˆØ§Ù„Ø¨ÙˆØªØ§Øª
        PlayerCount = 0,
        
        BotCount = 0,
        
        -- Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ø®Ø· ÙˆØ§Ù„Ø­Ø¬Ù… Ø§Ù„Ø£ØµÙ„ÙŠØ©
        FontSize = 16,          -- Ø­Ø¬Ù… Ø§Ù„Ø®Ø· Ø§Ù„Ø£Ø³Ø§Ø³ÙŠ
        TextScaleValue = 1.1,   -- Ù…Ø¹Ø§Ù…Ù„ ØªØ­Ø¬ÙŠÙ… Ø§Ù„Ù†Øµ
        
        -- Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„ØªØ¯Ø±Ø¬ ÙˆØ§Ù„Ù„ÙˆÙ† Ø§Ù„Ø£ØµÙ„ÙŠØ©
        NumLayers = 50,
        Red = 1.0,
        Green = 0.0,
        Blue = 0.0,
        LayerAlpha = 0.038,

        _CachedText = "",
        _CachedPosVec = nil
    }

    function RedBoxOverlay.Create()
        if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
            return true
        end

        local ParentCanvas = PlayerMapMarker.ESPCanvas
        if not ParentCanvas or not slua.isValid(ParentCanvas) then 
            if not PlayerMapMarker.InitESPCanvas() then return false end
            ParentCanvas = PlayerMapMarker.ESPCanvas
        end

        if not ParentCanvas or not slua.isValid(ParentCanvas) then return false end

        local Container = nil
        pcall(function()
            Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas)
        end)

        if not Container or not slua.isValid(Container) then return false end

        local FLinearColor = import("LinearColor") or FLinearColor
        local FVector2D = import("Vector2D") or FVector2D
        local color = FLinearColor(RedBoxOverlay.Red, RedBoxOverlay.Green, RedBoxOverlay.Blue, RedBoxOverlay.LayerAlpha)

        local numLayers = RedBoxOverlay.NumLayers
        local totalWidth = RedBoxOverlay.Width

        -- 1. Ø®Ù„ÙÙŠØ© Ø§Ù„Ù…Ø³ØªØ·ÙŠÙ„ Ø§Ù„Ù…ØªØ¯Ø±Ø¬Ø© (50 Ø·Ø¨Ù‚Ø© Ø¨Ù†ÙØ³ Ø§Ù„ØªØµÙ…ÙŠÙ… Ø§Ù„Ø£ØµÙ„ÙŠ)
        for i = 1, numLayers do
            local progress = (i / numLayers) ^ 1.15
            local layerWidth = progress * totalWidth
            local layerX = (totalWidth - layerWidth) / 2.0

            local border = nil
            pcall(function()
                border = CGame:NewObjectFromPath("/Script/UMG.Border", Container)
            end)

            if border and slua.isValid(border) then
                pcall(function()
                    border:SetBrushColor(color)
                    border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end)

                local slot = Container:AddChildToCanvas(border)
                if slot then
                    slot:SetPosition(FVector2D(layerX, 0))
                    slot:SetSize(FVector2D(layerWidth, RedBoxOverlay.Height))
                end
            end
        end

        -- 2. Ø¥Ù†Ø´Ø§Ø¡ ÙƒØ§Ø¦Ù† Ø§Ù„Ù†Øµ
        local txtWidget = nil
        pcall(function()
            txtWidget = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container)
        end)

        if txtWidget and slua.isValid(txtWidget) then
            pcall(function()
                local strText = string.format("Player: %d   Bot: %d", RedBoxOverlay.PlayerCount, RedBoxOverlay.BotCount)
                txtWidget:SetText(strText)
                RedBoxOverlay._CachedText = strText

                local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
                local whiteLinear = FLinearColor(1.0, 1.0, 1.0, 1.0)
                if FSlateColor then
                    txtWidget:SetColorAndOpacity(FSlateColor(whiteLinear))
                else
                    txtWidget:SetColorAndOpacity(whiteLinear)
                end

                if txtWidget.Font then
                    local font = txtWidget.Font
                    font.Size = RedBoxOverlay.FontSize
                    txtWidget.Font = font
                end

                txtWidget:SetRenderScale(FVector2D(RedBoxOverlay.TextScaleValue, RedBoxOverlay.TextScaleValue))
                txtWidget:SetRenderTransformPivot(FVector2D(0.5, 0.5))
                txtWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)

            local txtSlot = Container:AddChildToCanvas(txtWidget)
            if txtSlot then
                pcall(function()
                    txtSlot:SetAutoSize(true)
                    txtSlot:SetAlignment(FVector2D(0.5, 0.5))
                    txtSlot:SetPosition(FVector2D(totalWidth * 0.5, RedBoxOverlay.Height * 0.5))
                    txtSlot:SetZOrder(1000)
                end)
            end

            RedBoxOverlay.TextBlock = txtWidget
        end

        local MainSlot = nil
        pcall(function() MainSlot = ParentCanvas:AddChildToCanvas(Container) end)
        if not MainSlot then return false end

        RedBoxOverlay.MainContainer = Container
        RedBoxOverlay.WidgetSlot = MainSlot
        
        pcall(function()
            MainSlot:SetAutoSize(false)
            MainSlot:SetZOrder(999)
            MainSlot:SetAlignment(FVector2D(0.5, 0.0))
            MainSlot:SetSize(FVector2D(RedBoxOverlay.Width, RedBoxOverlay.Height))
        end)

        RedBoxOverlay.UpdatePosition()
        return true
    end

    function RedBoxOverlay.SetCounts(players, bots)
        if RedBoxOverlay.PlayerCount == players and RedBoxOverlay.BotCount == bots then
            return
        end

        RedBoxOverlay.PlayerCount = players or 0
        RedBoxOverlay.BotCount = bots or 0
        
        if RedBoxOverlay.TextBlock and slua.isValid(RedBoxOverlay.TextBlock) then
            pcall(function()
                local strText = string.format("Player: %d   Bot: %d", RedBoxOverlay.PlayerCount, RedBoxOverlay.BotCount)
                if RedBoxOverlay._CachedText ~= strText then
                    RedBoxOverlay.TextBlock:SetText(strText)
                    RedBoxOverlay._CachedText = strText
                end
            end)
        end
    end

    function RedBoxOverlay.UpdatePosition()
        local Slot = RedBoxOverlay.WidgetSlot
        if not Slot or not slua.isValid(Slot) then return end

        local PC = PlayerMapMarker.GetMyPlayerController()
        if not slua.isValid(PC) then return end

        local fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)

        pcall(function()
            if not RedBoxOverlay._CachedPosVec then
                RedBoxOverlay._CachedPosVec = import("Vector2D")(fromX, fromY)
            else
                RedBoxOverlay._CachedPosVec.X = fromX
                RedBoxOverlay._CachedPosVec.Y = fromY
            end
            Slot:SetPosition(RedBoxOverlay._CachedPosVec)
        end)
    end

    function RedBoxOverlay.Start()
        if RedBoxOverlay.bActive and RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return end
        if RedBoxOverlay.Create() then
            RedBoxOverlay.bActive = true
            pcall(function()
                RedBoxOverlay.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
        end
    end

    function RedBoxOverlay.Stop()
        RedBoxOverlay.bActive = false
        if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
            pcall(function()
                RedBoxOverlay.MainContainer:RemoveFromParent()
                RedBoxOverlay.MainContainer:ConditionalBeginDestroy()
            end)
        end
        RedBoxOverlay.MainContainer = nil
        RedBoxOverlay.WidgetSlot = nil
        RedBoxOverlay.TextBlock = nil
        RedBoxOverlay._CachedPosVec = nil
    end

    _G.RedBoxOverlay = RedBoxOverlay
    -- ============================================================
    -- ESP & MARKER SYSTEM CODE
    -- ============================================================

    local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")

    local SlateBlueprintLibrary = nil
    local WidgetLayoutLibrary = nil
    local KismetMathLibrary = nil
    local KismetSystemLibrary = nil

    pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary") end)
    pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary") end)
    pcall(function() KismetMathLibrary = import("KismetMathLibrary") end)
    pcall(function() KismetSystemLibrary = import("KismetSystemLibrary") end)

    PlayerMapMarker.MarkTypeID = 1007
    PlayerMapMarker.bUseScreenESP = true
    PlayerMapMarker.bUseScreenMark = false
    PlayerMapMarker.bUseQuickSign = false
    PlayerMapMarker.bUseNavigator = false
    PlayerMapMarker.bUseWidgetComponent = false
    PlayerMapMarker.QuickSignConfigKey = "C_MarkPos"

    PlayerMapMarker.WidgetCompUIPath = "/Game/BluePrints/ControlInput/NewbieItem/NewbieTips_ConsumeTips.NewbieTips_ConsumeTips"
    PlayerMapMarker.WidgetCompBoneName = "head"
    PlayerMapMarker.WidgetCompOffset = FVector(0, 0, 80)
    PlayerMapMarker.WidgetCompDrawSize = FVector2D(300, 50)

    PlayerMapMarker.ESPBoneName = "head"
    PlayerMapMarker.ESPWorldOffsetZ = 0
    PlayerMapMarker.ESPScreenOffsetY = 0

    PlayerMapMarker.ESPAnchorOffsetX = 50
    PlayerMapMarker.ESPAnchorOffsetY = 0
    PlayerMapMarker.ESPTextOffsetX = 0
    PlayerMapMarker.ESPTextOffsetY = 0

    PlayerMapMarker.ESPWidgetAlignment = FVector2D(0.5, 1.0)
    PlayerMapMarker.ESPWidgetSize = FVector2D(100, 30)
    PlayerMapMarker.ESPWidgetAutoSize = true
    PlayerMapMarker.ESPWidgetZOrder = 2

    PlayerMapMarker.bShowDistance = true
    PlayerMapMarker.DistanceUnit = "m"

    PlayerMapMarker.WeaponIconBrushW = 138
    PlayerMapMarker.WeaponIconBrushH = 69
    PlayerMapMarker.HPWidgetSwitcherTypeIndex = 0
    PlayerMapMarker.HPWidgetSwitcherType2Index = 0
    PlayerMapMarker.bForceSwitcherIndexEveryUpdate = true

    PlayerMapMarker.bUseSnapLines = true
    PlayerMapMarker.SnapLineThickness = 1.5
    PlayerMapMarker.SnapLineOriginY = 50
    PlayerMapMarker.SnapLineOriginOffsetX = 0
    PlayerMapMarker.SnapLineHeadOffsetX = 0
    PlayerMapMarker.SnapLineHeadOffsetY = -20
    PlayerMapMarker.SnapLineColor = nil
    PlayerMapMarker.SnapLineOpacity = 0.7

    PlayerMapMarker.MapAddedFlag = 4
    PlayerMapMarker.nUpdateInterval = 0.5

    PlayerMapMarker.bUseFrameTick = false
    PlayerMapMarker.nHeavyScanFrameInterval = 15
    PlayerMapMarker.nDistanceUpdateFrameInterval = 5

    PlayerMapMarker.bIncludeMe = false
    PlayerMapMarker.bIncludeAI = true
    PlayerMapMarker.bUseServerMarks = false

    PlayerMapMarker.bActive = false
    PlayerMapMarker.MarkMap = {}
    PlayerMapMarker.PlayerInfo = {}

    PlayerMapMarker.ESPCanvas = nil
    PlayerMapMarker.ESPWidgets = {}
    PlayerMapMarker.ESPWidgetPtrs = {}
    PlayerMapMarker.SnapLineWidgets = {}

    PlayerMapMarker._cachedViewportW = 1920
    PlayerMapMarker._cachedViewportH = 1080

    PlayerMapMarker._FrameCount = 0
    PlayerMapMarker._bTickRegistered = false
    PlayerMapMarker._CachedAllChars = nil
    PlayerMapMarker._CachedMyLoc = nil
    PlayerMapMarker._CachedMyKey = nil

    PlayerMapMarker.WidgetComps = {}
    PlayerMapMarker._bAllPathsFailed = false

    PlayerMapMarker._bLightUpdateScheduled = false
    PlayerMapMarker._LightUpdateInterval = 0.05

    PlayerMapMarker._bDistanceUpdateScheduled = false
    PlayerMapMarker._DistanceUpdateInterval = 0.1

    local function IsValid(obj)
        if obj == nil then return false end
        if slua and slua.isValid then return slua.isValid(obj) end
        return obj ~= nil
    end

    local function SafeStr(val)
        if val == nil then return "nil" end
        return tostring(val)
    end

    local function GetFVector(X, Y, Z)
        local VT = FVector
        if not VT then
            pcall(function() VT = import("/Script/CoreUObject.Vector") end)
        end
        if VT then
            local ok, vec = pcall(function() return VT(X or 0, Y or 0, Z or 0) end)
            if ok and vec then return vec end
        end
        return nil
    end

    local function GetMapAddedFlag()
        if PlayerMapMarker.MapAddedFlag ~= nil then
            return PlayerMapMarker.MapAddedFlag
        end
        if UEnums and UEnums.EAddMarkFlag and UEnums.EAddMarkFlag.EAMF_Both then
            return UEnums.EAddMarkFlag.EAMF_Both
        end
        return 3
    end

    PlayerMapMarker._bScreenMarkConfigSetup = false

    function PlayerMapMarker.SetupScreenMarkConfig()
        if PlayerMapMarker._bScreenMarkConfigSetup then return true end
        local bOK = false
        pcall(function()
            local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
            local ScreenMarkConfig = GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
            if ScreenMarkConfig then
                ScreenMarkConfig[1007] = {
                    UIPathName = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP_C",
                    MaxWidgetNum = 100,
                    MaxShowDistance = 6000000,
                    bBindOutScreen = false,
                    bBindBlocked = true,
                    bNeedPreLoad = true,
                    bIsBindingActor = true,
                    BindSocketName = "HelmetSocket",
                    WorldPositionOffset = FVector(0, 0, 80)
                }
                PlayerMapMarker._bScreenMarkConfigSetup = true
                bOK = true
            end
        end)
        return bOK
    end

    function PlayerMapMarker.GetGameplayData()
        if PlayerMapMarker._CachedGameplayData then
            return PlayerMapMarker._CachedGameplayData
        end
        local ok, GDP = pcall(function()
            return require("GameLua.GameCore.Data.GameplayData")
        end)
        if ok and GDP then
            PlayerMapMarker._CachedGameplayData = GDP
            return GDP
        end
        return nil
    end

    function PlayerMapMarker.GetMyPlayerController()
        local PC = PlayerMapMarker._CachedPC
        if PC and IsValid(PC) then
            return PC
        end
        local GDP = PlayerMapMarker.GetGameplayData()
        if not GDP then return nil end
        pcall(function() PC = GDP.GetPlayerController and GDP.GetPlayerController() end)
        if PC and IsValid(PC) then
            PlayerMapMarker._CachedPC = PC
            return PC
        end
        return nil
    end

    function PlayerMapMarker.GetCGameState()
        if CGameState and IsValid(CGameState) then
            return CGameState
        end
        if PlayerMapMarker._CachedCGameState and IsValid(PlayerMapMarker._CachedCGameState) then
            return PlayerMapMarker._CachedCGameState
        end
        local ok, GS = pcall(function()
            return require("GameLua.GameCore.Data.CGameState")
        end)
        if ok and GS then
            PlayerMapMarker._CachedCGameState = GS
            return GS
        end
        return nil
    end

    function PlayerMapMarker.GetAllCharacters()
        local AllChars = {}
        pcall(function()
            local Pawns = Game:GetAllPlayerPawns()
            if Pawns then
                for _, Pawn in pairs(Pawns) do
                    if Pawn and slua.isValid(Pawn) then
                        local pKey = nil
                        if Pawn.GetPlayerKey then
                            pKey = Pawn:GetPlayerKey()
                        end
                        if not pKey and Pawn.PlayerKey then
                            pKey = Pawn.PlayerKey
                        end
                        if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then
                            pKey = Pawn.PlayerState.PlayerKey
                        end
                        if pKey then
                            AllChars[pKey] = Pawn
                        end
                    end
                end
            end
        end)
        
        if not next(AllChars) then
            local GS = PlayerMapMarker.GetCGameState()
            if GS and GS.GetAllCharacters then
                pcall(function() AllChars = GS:GetAllCharacters() end)
            end
        end
        
        return AllChars
    end

    function PlayerMapMarker.GetMyPlayerKey()
        local PC = PlayerMapMarker.GetMyPlayerController()
        if not IsValid(PC) then return nil end
        local MyKey = nil
        pcall(function()
            if PC.GetPlayerKey then
                MyKey = PC:GetPlayerKey()
            elseif PC.PlayerState and PC.PlayerState.PlayerKey then
                MyKey = PC.PlayerState.PlayerKey
            end
        end)
        return MyKey
    end

    function PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
        local bIsMe = false
        pcall(function()
            local GDP = PlayerMapMarker.GetGameplayData()
            if GDP and GDP.GetLocalCharacter then
                local MyChar = GDP.GetLocalCharacter()
                if MyChar and Character == MyChar then
                    bIsMe = true
                    return
                end
            end
            local PC = PlayerMapMarker.GetMyPlayerController()
            if PC and PC.GetPawn then
                local Pawn = PC:GetPawn()
                if Pawn and Character == Pawn then
                    bIsMe = true
                    return
                end
            end
        end)
        if not bIsMe and MyKey ~= nil and PlayerKey ~= nil then
            bIsMe = (tostring(PlayerKey) == tostring(MyKey))
        end
        return bIsMe
    end

    function PlayerMapMarker.GetCharacterLocation(Character)
        if not IsValid(Character) then return nil end
        local Loc = nil
        pcall(function()
            if Character.K2_GetActorLocation then
                Loc = Character:K2_GetActorLocation()
            end
        end)
        if not Loc then
            pcall(function()
                if Game and Game.GetActorLocation then
                    Loc = Game:GetActorLocation(Character)
                end
            end)
        end
        return Loc
    end

    function PlayerMapMarker.CalcDistance(Loc1, Loc2)
        if not Loc1 or not Loc2 then return nil end
        local Dist = nil
        pcall(function()
            if FVector and FVector.Dist2D then
                Dist = FVector.Dist2D(Loc1, Loc2)
            end
        end)
        if not Dist then
            pcall(function()
                local DX = (Loc1.X or 0) - (Loc2.X or 0)
                local DY = (Loc1.Y or 0) - (Loc2.Y or 0)
                Dist = math.sqrt(DX * DX + DY * DY)
            end)
        end
        return Dist
    end

    function PlayerMapMarker.GetDistanceString(MyLoc, TargetLoc)
        if not PlayerMapMarker.bShowDistance then return "" end
        if not MyLoc or not TargetLoc then return "" end
        local Dist = PlayerMapMarker.CalcDistance(MyLoc, TargetLoc)
        if not Dist then return "" end
        local Meters = Dist / 100
        if Meters < 1000 then
            return string.format("%dm", math.floor(Meters))
        else
            return string.format("%.1fkm", Meters / 1000)
        end
    end

    function PlayerMapMarker.GetMyLocation()
        local GDP = PlayerMapMarker.GetGameplayData()
        if not GDP then return nil end
        local MyChar = nil
        pcall(function() MyChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter() end)
        if not IsValid(MyChar) then
            local PC = PlayerMapMarker.GetMyPlayerController()
            if IsValid(PC) then
                pcall(function()
                    if PC.GetPawn then
                        local Pawn = PC:GetPawn()
                        if IsValid(Pawn) and Pawn.K2_GetActorLocation then
                            return Pawn:K2_GetActorLocation()
                        end
                    end
                end)
            end
            return nil
        end
        return PlayerMapMarker.GetCharacterLocation(MyChar)
    end

    function PlayerMapMarker.GetPlayerName(Character)
        if not IsValid(Character) then return "Unknown" end
        local Name = nil
        pcall(function()
            if Character.GetPlayerNameSafety then
                Name = Character:GetPlayerNameSafety()
            end
        end)
        if not Name then
            pcall(function()
                local PS = nil
                if Character.GetPlayerStateSafety then
                    PS = Character:GetPlayerStateSafety()
                elseif Character.GetPlayerState then
                    PS = Character:GetPlayerState()
                end
                if IsValid(PS) and PS.GetPlayerName then
                    Name = PS:GetPlayerName()
                end
            end)
        end
        return Name or "Unknown"
    end

    function PlayerMapMarker.IsAI(Character)
        local bAI = false
        pcall(function()
            if Game and Game.IsAI then
                bAI = Game:IsAI(Character)
            end
        end)
        return bAI
    end

    function PlayerMapMarker.IsAlive(Character)
        local bAlive = true
        pcall(function()
            if Character.IsAlive then
                bAlive = Character:IsAlive()
            end
        end)
        return bAlive
    end

    function PlayerMapMarker.GetQuickSignComponent()
        local PC = PlayerMapMarker.GetMyPlayerController()
        if not IsValid(PC) then return nil end
        local QSC = nil
        pcall(function()
            if PC.GetQuickSignComponent then
                QSC = PC:GetQuickSignComponent()
            end
        end)
        if not IsValid(QSC) then
            pcall(function()
                local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
                if STExtraBlueprintFunctionLibrary and STExtraBlueprintFunctionLibrary.GetQuickSignComponentFromController then
                    QSC = STExtraBlueprintFunctionLibrary.GetQuickSignComponentFromController(PC)
                end
            end)
        end
        return QSC
    end

    function PlayerMapMarker.CreateQuickSignMark(Location)
        if not Location then return nil end
        local QSC = PlayerMapMarker.GetQuickSignComponent()
        if not IsValid(QSC) then return nil end
        local MsgID = nil
        pcall(function()
            if QSC.MakeCustomMark then
                MsgID = QSC:MakeCustomMark(Location, PlayerMapMarker.QuickSignConfigKey)
            end
        end)
        return MsgID
    end

    function PlayerMapMarker.RemoveQuickSignMark(MsgID)
        if not MsgID then return end
        local QSC = PlayerMapMarker.GetQuickSignComponent()
        if not IsValid(QSC) then return end
        pcall(function()
            if QSC.DealWithDelMsg then
                QSC:DealWithDelMsg(MsgID, false)
            end
        end)
    end

    PlayerMapMarker._NavInstIDCounter = 1000
    PlayerMapMarker.NavigatorUIPath = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP_C"
    PlayerMapMarker.NavigatorbIsIcon = true

    function PlayerMapMarker.CreateNavigatorMark(Location)
        if not Location then return nil end
        local InstID = PlayerMapMarker._NavInstIDCounter
        PlayerMapMarker._NavInstIDCounter = PlayerMapMarker._NavInstIDCounter + 1
        local NavWidget = nil
        pcall(function()
            if UIManager and UIManager.UI_Config_InGame and UIManager.UI_Config_InGame.NavigatorPanel then
                NavWidget = UIManager.GetUI(UIManager.UI_Config_InGame.NavigatorPanel)
            end
        end)
        if not NavWidget then return nil end
        local Result = nil
        pcall(function()
            Result = InGameMarkTools.ClientAddMarkToNavigator(
                PlayerMapMarker.NavigatorUIPath,
                Location,
                true,
                PlayerMapMarker.NavigatorbIsIcon,
                nil,
                InstID
            )
        end)
        return InstID
    end

    function PlayerMapMarker.UpdateNavigatorMark(InstID, Location)
        if not InstID or not Location then return end
        pcall(function()
            if not UIManager.UI_Config_InGame.NavigatorPanel then return end
            local NavigatorWidget = UIManager.GetUI(UIManager.UI_Config_InGame.NavigatorPanel)
            if not NavigatorWidget then return end
            if NavigatorWidget.UpdateCustomMarkLocation then
                NavigatorWidget:UpdateCustomMarkLocation(InstID, Location)
            end
        end)
    end

    function PlayerMapMarker.RemoveNavigatorMark(InstID)
        if not InstID then return end
        pcall(function()
            InGameMarkTools.ClientDestroyMarkToNavigator(InstID)
        end)
    end

    function PlayerMapMarker.IsOurESPWidget(w)
        if not w or not slua.isValid(w) then return false end
        local bIsOurs = false
        pcall(function()
            local wstr = tostring(w)
            for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
                if ESPData and ESPData.Widget and ESPData.Widget.Container then
                    local cstr = tostring(ESPData.Widget.Container)
                    if cstr == wstr then
                        bIsOurs = true
                        return
                    end
                end
            end
        end)
        if bIsOurs then return true end
        pcall(function()
            if w.GetChildrenCount then
                local n = w:GetChildrenCount()
                for i = 0, n - 1 do
                    local child = w:GetChildAt(i)
                    if child and slua.isValid(child) then
                        local cstr = tostring(child)
                        if string.find(cstr, "Border") then
                            bIsOurs = true
                            break
                        end
                    end
                end
            end
        end)
        if not bIsOurs then
            pcall(function()
                local slot = w.Slot
                if slot and slot.GetPosition then
                    local pos = slot:GetPosition()
                    if pos and (math.abs(pos.X or 0) > 1 or math.abs(pos.Y or 0) > 1) then
                        bIsOurs = true
                    end
                end
            end)
        end
        if not bIsOurs then
            pcall(function()
                local function checkForDist(w2, depth)
                    if not w2 or not slua.isValid(w2) or depth > 5 then return false end
                    if w2.GetText then
                        local txt = nil
                        pcall(function() txt = w2:GetText() end)
                        if txt then
                            local s = tostring(txt)
                            if string.find(s, "%[%d+m%]") or string.find(s, "Dist=") then
                                return true
                            end
                        end
                    end
                    local n = 0
                    pcall(function() if w2.GetChildrenCount then n = w2:GetChildrenCount() end end)
                    for j = 0, n - 1 do
                        local c = nil
                        pcall(function() c = w2:GetChildAt(j) end)
                        if c and checkForDist(c, depth + 1) then return true end
                    end
                    return false
                end
                bIsOurs = checkForDist(w, 0)
            end)
        end
        return bIsOurs
    end

    function PlayerMapMarker.ApplyAnchorBasedPosition(Slot, ScreenPos, Canvas)
        if not Slot or not ScreenPos then return false end
        local sx = ScreenPos.X or 0
        local sy = ScreenPos.Y or 0
        local sz = PlayerMapMarker.ESPWidgetSize or FVector2D(100, 30)
        local align = PlayerMapMarker.ESPWidgetAlignment or FVector2D(0.5, 1.0)

        local canvasW, canvasH = 0, 0
        if PlayerMapMarker._cachedViewportW and PlayerMapMarker._cachedViewportW > 200 then
            canvasW = PlayerMapMarker._cachedViewportW
            canvasH = PlayerMapMarker._cachedViewportH
        end

        if canvasW < 200 then
            pcall(function()
                local PC = PlayerMapMarker.GetMyPlayerController()
                if IsValid(PC) and PC.GetViewportSize then
                    local VS = FVector2D(0, 0)
                    PC:GetViewportSize(VS)
                    if VS and VS.X and VS.X > 200 then
                        canvasW = VS.X
                        canvasH = VS.Y
                        PlayerMapMarker._cachedViewportW = canvasW
                        PlayerMapMarker._cachedViewportH = canvasH
                    end
                end
            end)
        end

        if canvasW < 200 and Canvas then
            pcall(function()
                local current = Canvas
                local depth = 0
                while current and depth < 20 do
                    local w, h = 0, 0
                    pcall(function()
                        if current.GetCachedGeometry then
                            local cg = current:GetCachedGeometry()
                            if cg then
                                if cg.GetAbsoluteSize then
                                    local cs = cg:GetAbsoluteSize()
                                    if cs then
                                        w = cs.X or 0
                                        h = cs.Y or 0
                                    end
                                end
                            end
                        end
                    end)
                    if w >= 200 and h >= 200 then
                        canvasW = w
                        canvasH = h
                        PlayerMapMarker._cachedViewportW = w
                        PlayerMapMarker._cachedViewportH = h
                        break
                    end
                    local parent = nil
                    pcall(function() if current.GetParent then parent = current:GetParent() end end)
                    if not parent then break end
                    current = parent
                    depth = depth + 1
                end
            end)
        end

        if canvasW > 200 and canvasH > 200 then
            local anchorX = (sx + (PlayerMapMarker.ESPAnchorOffsetX or 0)) / canvasW
            local anchorY = (sy + (PlayerMapMarker.ESPAnchorOffsetY or 0)) / canvasH
            anchorX = math.max(0, math.min(1, anchorX))
            anchorY = math.max(0, math.min(1, anchorY))

            local bSuccess = false
            pcall(function()
                if Slot.SetAnchors and FAnchors then
                    local anchors = FAnchors(anchorX, anchorY, anchorX, anchorY)
                    if anchors then
                        Slot:SetAnchors(anchors)
                        Slot:SetPosition(FVector2D(0, 0))
                        bSuccess = true
                    end
                end
            end)
            if not bSuccess then
                pcall(function()
                    if Slot.SetAnchors then
                        Slot:SetAnchors(anchorX, anchorY, anchorX, anchorY)
                        Slot:SetPosition(FVector2D(0, 0))
                        bSuccess = true
                    end
                end)
            end
            if bSuccess then
                pcall(function()
                    if Slot.SetOffsets and FMargin then
                        Slot:SetOffsets(FMargin(0, 0, sz.X, sz.Y))
                    end
                end)
                pcall(function() Slot:SetSize(sz) end)
                pcall(function() Slot:SetAlignment(align) end)
                pcall(function() if Slot.SetAutoSize then Slot:SetAutoSize(PlayerMapMarker.ESPWidgetAutoSize or true) end end)
                pcall(function() if Slot.SetZOrder then Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 2) end end)
                return true
            end
        end

        pcall(function()
            Slot:SetPosition(FVector2D(sx, sy))
            pcall(function() Slot:SetSize(sz) end)
            pcall(function() Slot:SetAlignment(align) end)
            pcall(function() if Slot.SetAutoSize then Slot:SetAutoSize(PlayerMapMarker.ESPWidgetAutoSize or true) end end)
            pcall(function() if Slot.SetZOrder then Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 2) end end)
        end)
        return false
    end

    function PlayerMapMarker.InitESPCanvas()
        if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
            return true
        end

        local InGameUITools = nil
        pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
        if not InGameUITools then
            return false
        end

        local MainControlBaseUI = nil
        pcall(function() MainControlBaseUI = InGameUITools.GetMainControlBaseUI() end)
        if not MainControlBaseUI or not Game:IsValid(MainControlBaseUI) then
            return false
        end

        local ParentCanvas = nil
        pcall(function()
            if MainControlBaseUI.CanvasPanel_0 and Game:IsValid(MainControlBaseUI.CanvasPanel_0) then
                ParentCanvas = MainControlBaseUI.CanvasPanel_0
            elseif MainControlBaseUI.CanvasPanel_42 and Game:IsValid(MainControlBaseUI.CanvasPanel_42) then
                ParentCanvas = MainControlBaseUI.CanvasPanel_42
            end
        end)

        if not ParentCanvas then
            return false
        end

        PlayerMapMarker.ESPCanvas = ParentCanvas

        pcall(function()
            local nChildren = ParentCanvas:GetChildrenCount()
            for i = nChildren - 1, 0, -1 do
                local child = ParentCanvas:GetChildAt(i)
                if child and slua.isValid(child) then
                    if PlayerMapMarker.IsOurESPWidget(child) then
                        pcall(function() ParentCanvas:RemoveChild(child) end)
                    end
                end
            end
        end)

        return true
    end

    function PlayerMapMarker.FindProgressBarInWidget(WidgetObj, Depth, MaxDepth)
        if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
        Depth = Depth or 0
        MaxDepth = MaxDepth or 5
        if Depth > MaxDepth then return nil end

        local bIsPB = false
        pcall(function()
            if WidgetObj.SetPercent and WidgetObj.SetFillColorAndOpacity then
                bIsPB = true
            end
        end)
        if bIsPB then return WidgetObj end

        local nChildren = 0
        pcall(function()
            if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end
        end)

        for i = 0, math.max(nChildren - 1, 0) do
            local child = nil
            pcall(function() child = WidgetObj:GetChildAt(i) end)
            if child and slua.isValid(child) then
                local result = PlayerMapMarker.FindProgressBarInWidget(child, Depth + 1, MaxDepth)
                if result then return result end
            end
        end

        return nil
    end

    function PlayerMapMarker.GetTeamID(Character)
        if not IsValid(Character) then return nil end
        local TeamID = nil
        pcall(function()
            if Character.GetTeamID then TeamID = Character:GetTeamID() end
        end)
        if not TeamID then
            pcall(function()
                local PS = nil
                if Character.GetPlayerStateSafety then
                    PS = Character:GetPlayerStateSafety()
                elseif Character.GetPlayerState then
                    PS = Character:GetPlayerState()
                end
                if IsValid(PS) and PS.GetTeamID then
                    TeamID = PS:GetTeamID()
                elseif IsValid(PS) and PS.TeamID then
                    TeamID = PS.TeamID
                end
            end)
        end
        if not TeamID then
            pcall(function()
                if Character.TeamID then TeamID = Character.TeamID end
            end)
        end
        return TeamID
    end

    function PlayerMapMarker.GetTeamColor(TeamID)
        if TeamID == nil then return nil end
        local TeamColors = {
            [1] = FLinearColor(1.0, 0.2, 0.2, 1.0),
            [2] = FLinearColor(0.2, 0.4, 1.0, 1.0),
            [3] = FLinearColor(0.2, 0.9, 0.3, 1.0),
            [4] = FLinearColor(1.0, 0.9, 0.2, 1.0),
            [5] = FLinearColor(0.8, 0.3, 1.0, 1.0),
            [6] = FLinearColor(0.2, 0.9, 0.9, 1.0),
            [7] = FLinearColor(1.0, 0.5, 0.2, 1.0),
            [8] = FLinearColor(1.0, 0.4, 0.7, 1.0),
        }
        local color = TeamColors[TeamID]
        if color then return color end
        if TeamID == 1 then
            return FLinearColor(1.0, 0.2, 0.2, 1.0)
        else
            return FLinearColor(0.2, 0.4, 1.0, 1.0)
        end
    end

    local _WhiteTexture = nil
    local _bWhiteTextureFailed = false

    local function GetWhiteTexture()
        if _WhiteTexture then return _WhiteTexture end
        if _bWhiteTextureFailed then return nil end
        pcall(function()
            local paths = {
                "/Game/BluePrints/UI/Textures/White.White",
                "/Game/BluePrints/UI/Textures/Common/White.White",
                "/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture",
                "/Engine/EngineMaterials/DefaultWhiteGrid.DefaultWhiteGrid",
            }
            for _, path in ipairs(paths) do
                pcall(function()
                    local tex = import(path)
                    if tex and slua.isValid(tex) then
                        _WhiteTexture = tex
                        return
                    end
                end)
                if _WhiteTexture then break end
            end
        end)
        if not _WhiteTexture then
            _bWhiteTextureFailed = true
        end
        return _WhiteTexture
    end

    local function SetImageColor(Image, color)
        if not Image or not slua.isValid(Image) then return false end
        local bOK = false
        pcall(function()
            if Image.SetBrushTintColor then
                Image:SetBrushTintColor(color)
                bOK = true
            end
        end)
        pcall(function()
            if Image.SetBrushColor then
                Image:SetBrushColor(color)
                bOK = true
            end
        end)
        pcall(function()
            if Image.SetColorAndOpacity then
                Image:SetColorAndOpacity(color)
                bOK = true
            end
        end)
        pcall(function()
            if Image.SetTintColorAndOpacity then
                Image:SetTintColorAndOpacity(color)
                bOK = true
            end
        end)
        pcall(function()
            if Image.SetBrushFromTexture then
                local whiteTex = GetWhiteTexture()
                if whiteTex then
                    Image:SetBrushFromTexture(whiteTex, false)
                    if Image.SetColorAndOpacity then
                        Image:SetColorAndOpacity(color)
                    end
                    if Image.SetBrushTintColor then
                        Image:SetBrushTintColor(color)
                    end
                    bOK = true
                end
            end
        end)
        pcall(function()
            if Image.SetBrushFromAsset and not bOK then
                Image:SetBrushFromAsset("/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture", false)
                if Image.SetColorAndOpacity then
                    Image:SetColorAndOpacity(color)
                end
                bOK = true
            end
        end)
        pcall(function() Image:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function() Image:SetRenderOpacity(1.0) end)
        return bOK
    end

    function PlayerMapMarker._GetWidgetRoot(WidgetObj)
        if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
        local Root = nil
        pcall(function()
            if WidgetObj.GetRootWidget then
                Root = WidgetObj:GetRootWidget()
            end
        end)
        if Root and slua.isValid(Root) then return Root end
        pcall(function()
            if WidgetObj.WidgetTree and WidgetObj.WidgetTree.RootWidget then
                Root = WidgetObj.WidgetTree.RootWidget
            end
        end)
        if Root and slua.isValid(Root) then return Root end
        pcall(function()
            if WidgetObj.RootWidget and slua.isValid(WidgetObj.RootWidget) then
                Root = WidgetObj.RootWidget
            end
        end)
        return Root
    end

    function PlayerMapMarker._FindNamedWidgetInTree(WidgetObj, TargetName, MaxDepth)
        if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
        MaxDepth = MaxDepth or 8

        local wname = nil
        pcall(function()
            if WidgetObj.GetName then wname = WidgetObj:GetName() end
        end)
        if wname and wname == TargetName then return WidgetObj end

        local wstr = tostring(WidgetObj)
        if wstr and string.find(wstr, TargetName, 1, true) then
            if wname and wname == TargetName then
                return WidgetObj
            elseif not wname or wname == "" then
                local _, endPos = string.find(wstr, TargetName, 1, true)
                if endPos then
                    local nextChar = string.sub(wstr, endPos + 1, endPos + 1)
                    if nextChar ~= "_" and nextChar ~= "" then
                        return WidgetObj
                    end
                end
            end
        end

        local nChildren = 0
        pcall(function()
            if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end
        end)

        if nChildren > 0 then
            for i = 0, nChildren - 1 do
                local child = nil
                pcall(function() child = WidgetObj:GetChildAt(i) end)
                if child and slua.isValid(child) then
                    local found = PlayerMapMarker._FindNamedWidgetInTree(child, TargetName, MaxDepth - 1)
                    if found then return found end
                end
            end
        else
            local Root = PlayerMapMarker._GetWidgetRoot(WidgetObj)
            if Root and slua.isValid(Root) and Root ~= WidgetObj then
                local found = PlayerMapMarker._FindNamedWidgetInTree(Root, TargetName, MaxDepth - 1)
                if found then return found end
            end
        end

        return nil
    end

    function PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
        if not Widget or not Widget.Container then return end
        local color = PlayerMapMarker.GetTeamColor(TeamID)
        if not color then return end

        pcall(function()
            local W = Widget.Container
            if not W or not slua.isValid(W) then return end

            local bBG = false
            local Image_TeamBG = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamBG", 8)
            if Image_TeamBG and slua.isValid(Image_TeamBG) then
                bBG = SetImageColor(Image_TeamBG, color)
            end

            local Image_TeamLogoBG = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamLogoBG", 8)
            if Image_TeamLogoBG and slua.isValid(Image_TeamLogoBG) then
                SetImageColor(Image_TeamLogoBG, color)
            end

            if not bBG then
                if W.Image_TeamBG_2 and slua.isValid(W.Image_TeamBG_2) then
                    bBG = SetImageColor(W.Image_TeamBG_2, color)
                end
                if W.Image_TeamLogoBG2 and slua.isValid(W.Image_TeamLogoBG2) then
                    SetImageColor(W.Image_TeamLogoBG2, color)
                end
                if W.Image_TeamLogoBegin and slua.isValid(W.Image_TeamLogoBegin) then
                    SetImageColor(W.Image_TeamLogoBegin, color)
                end
            end

            if W.SetTeamColor then
                pcall(function() W:SetTeamColor(TeamID) end)
            end
            if W.SetTeamID then
                pcall(function() W:SetTeamID(TeamID) end)
            end

            if not Widget.TeamBgBorder or not slua.isValid(Widget.TeamBgBorder) then
                pcall(function()
                    local Border = CGame:NewObjectFromPath("/Script/UMG.Border", W)
                    if Border and slua.isValid(Border) then
                        pcall(function() Border:SetBrushColor(color) end)
                        pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        pcall(function() Border:SetRenderOpacity(0.7) end)
                        pcall(function() Border:SetDesiredSizeOverride(FVector2D(120, 20)) end)
                        pcall(function()
                            if W.AddChild then
                                W:AddChild(Border)
                            end
                        end)
                        pcall(function()
                            if Border.SetZOrder then
                                Border:SetZOrder(-1)
                            end
                        end)
                        pcall(function()
                            local Slot = Border.Slot
                            if Slot then
                                if Slot.SetSize then
                                    Slot:SetSize(FVector2D(120, 40))
                                end
                                if Slot.SetPosition then
                                    Slot:SetPosition(FVector2D(0, 0))
                                end
                            end
                        end)
                        Widget.TeamBgBorder = Border
                    end
                end)
            else
                pcall(function()
                    Widget.TeamBgBorder:SetBrushColor(color)
                    Widget.TeamBgBorder:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    Widget.TeamBgBorder:SetRenderOpacity(0.7)
                end)
            end
        end)
    end

    function PlayerMapMarker.GetCharacterMesh(Character)
        if not IsValid(Character) then return nil end
        local Mesh = nil
        pcall(function()
            if Character.Mesh and Game:IsValid(Character.Mesh) then
                Mesh = Character.Mesh
            end
        end)
        if not Mesh then
            pcall(function()
                local SkeletalMeshCompClass = import("/Script/Engine.SkeletalMeshComponent")
                Mesh = Character:GetComponentByClass(SkeletalMeshCompClass)
            end)
        end
        return Mesh
    end

    function PlayerMapMarker.GetBoneLocation(Character, BoneName)
        if not IsValid(Character) or not BoneName then return nil end
        local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
        if not Mesh or not Game:IsValid(Mesh) then return nil end
        local Loc = nil
        pcall(function()
            if Mesh.GetSocketLocation then
                Loc = Mesh:GetSocketLocation(BoneName)
            end
        end)
        if not Loc then
            pcall(function()
                if Mesh.GetBoneLocation then
                    Loc = Mesh:GetBoneLocation(BoneName)
                end
            end)
        end
        return Loc
    end

    function PlayerMapMarker.ApplyWorldOffset(Loc, OffsetZ)
        if not Loc then return nil end
        if not OffsetZ or OffsetZ == 0 then return Loc end
        
        local ok = pcall(function()
            Loc.Z = Loc.Z + OffsetZ
        end)
        if ok then
            return Loc
        end

        local result = nil
        pcall(function()
            local X = Loc.X or 0
            local Y = Loc.Y or 0
            local Z = (Loc.Z or 0) + OffsetZ
            if FVector then
                result = FVector(X, Y, Z)
            end
        end)
        return result or Loc
    end

    function PlayerMapMarker.GetESPLocation(Character)
        if not IsValid(Character) then return nil end
        
        local BoneLoc = PlayerMapMarker.GetCharacterLocation(Character)
        if BoneLoc then
            local heightOffset = 85
            pcall(function()
                if Character.bIsCrouched then heightOffset = 60 end
                if Character.IsProne and Character:IsProne() then heightOffset = 30 end
            end)
            BoneLoc = PlayerMapMarker.ApplyWorldOffset(BoneLoc, heightOffset + (PlayerMapMarker.ESPWorldOffsetZ or 0))
        end
        
        return BoneLoc
    end

    function PlayerMapMarker.GetCharacterWeaponInfo(Character)
        if not IsValid(Character) then return nil end

        local WeaponID = nil
        local WeaponName = nil
        local WeaponIconPath = nil
        local WeaponIconTexture = nil
        local CurrentWeapon = nil

        pcall(function()
            if Character.GetCurrentWeapon then
                CurrentWeapon = Character:GetCurrentWeapon()
            end
        end)
        
        if not CurrentWeapon then
            pcall(function()
                CurrentWeapon = Character.CurrentWeapon
            end)
        end

        if not CurrentWeapon then
            pcall(function()
                if Character.GetWeaponManager then
                    local WM = Character:GetWeaponManager()
                    if WM and WM.GetCurrentWeapon then
                        CurrentWeapon = WM:GetCurrentWeapon()
                    end
                end
            end)
        end

        if not CurrentWeapon then
            pcall(function()
                if Character.GetInventoryComponent then
                    local IC = Character:GetInventoryComponent()
                    if IC and IC.GetCurrentWeapon then
                        CurrentWeapon = IC:GetCurrentWeapon()
                    end
                end
            end)
        end

        if CurrentWeapon and IsValid(CurrentWeapon) then
            pcall(function()
                if CurrentWeapon.GetWeaponID then
                    WeaponID = CurrentWeapon:GetWeaponID()
                end
            end)
            if not WeaponID then
                pcall(function()
                    WeaponID = CurrentWeapon.WeaponID
                end)
            end
            if not WeaponID then
                pcall(function()
                    if CurrentWeapon.GetItemID then
                        WeaponID = CurrentWeapon:GetItemID()
                    end
                end)
            end
            
            pcall(function()
                if CurrentWeapon.GetWeaponName then
                    WeaponName = CurrentWeapon:GetWeaponName()
                end
            end)
            if not WeaponName then
                pcall(function()
                    WeaponName = CurrentWeapon.WeaponName
                end)
            end
            
            pcall(function()
                if CurrentWeapon.GetWeaponIconPath then
                    WeaponIconPath = CurrentWeapon:GetWeaponIconPath()
                end
            end)
            if not WeaponIconPath then
                pcall(function()
                    WeaponIconPath = CurrentWeapon.IconPath
                end)
            end
            
            pcall(function()
                if CurrentWeapon.GetWeaponIcon then
                    WeaponIconTexture = CurrentWeapon:GetWeaponIcon()
                end
            end)
            if not WeaponIconTexture then
                pcall(function()
                    WeaponIconTexture = CurrentWeapon.IconTexture
                end)
            end
        end

        if not WeaponID then
            pcall(function()
                local PS = nil
                if Character.GetPlayerStateSafety then
                    PS = Character:GetPlayerStateSafety()
                elseif Character.GetPlayerState then
                    PS = Character:GetPlayerState()
                end
                if PS and IsValid(PS) then
                    if PS.GetCurrentWeaponID then WeaponID = PS:GetCurrentWeaponID() end
                    if not WeaponID and PS.CurrentWeaponID then WeaponID = PS.CurrentWeaponID end
                    if not WeaponID and PS.WeaponID then WeaponID = PS.WeaponID end
                    if not WeaponID and PS.HoldWeaponID then WeaponID = PS.HoldWeaponID end
                    if not WeaponID and PS.CurWeaponID then WeaponID = PS.CurWeaponID end
                    if not WeaponID and PS.EquipWeaponID then WeaponID = PS.EquipWeaponID end
                end
            end)
        end
        
        if not WeaponID then
            pcall(function()
                if Character.WeaponID then WeaponID = Character.WeaponID end
                if not WeaponID and Character.CurrentWeaponID then WeaponID = Character.CurrentWeaponID end
                if not WeaponID and Character.HoldWeaponID then WeaponID = Character.HoldWeaponID end
                if not WeaponID and Character.CurWeaponID then WeaponID = Character.CurWeaponID end
                if not WeaponID and Character.EquipWeaponID then WeaponID = Character.EquipWeaponID end
                if not WeaponID and Character.WeaponManagerComponent then
                    local WMC = Character.WeaponManagerComponent
                    if WMC.CurrentWeaponID then WeaponID = WMC.CurrentWeaponID end
                    if not WeaponID and WMC.WeaponID then WeaponID = WMC.WeaponID end
                    if not WeaponID and WMC.HoldWeaponID then WeaponID = WMC.HoldWeaponID end
                    if not WeaponID and WMC.CurWeaponID then WeaponID = WMC.CurWeaponID end
                end
            end)
        end

        return {
            WeaponID = WeaponID,
            WeaponName = WeaponName,
            WeaponIconPath = WeaponIconPath,
            WeaponIconTexture = WeaponIconTexture,
            CurrentWeapon = CurrentWeapon,
        }
    end

    function PlayerMapMarker.FindWeaponIconInWidget(WidgetObj, Depth, MaxDepth)
        if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
        Depth = Depth or 0
        MaxDepth = MaxDepth or 8

        local propNames = {
            "Image_Weapon", "Image_WeaponIcon", "Image_Gun", "Image_Icon",
            "WeaponIcon", "WeaponImage", "WeaponIconImage",
            "Image_Equip", "Image_WeaponIcon_2", "Image_WeaponIcon2",
        }
        
        for _, pname in ipairs(propNames) do
            pcall(function()
                local prop = WidgetObj[pname]
                if prop and slua.isValid(prop) then
                    local hasBrush = false
                    pcall(function() if prop.Brush then hasBrush = true end end)
                    if hasBrush then
                        return prop
                    end
                end
            end)
        end

        if Depth >= MaxDepth then
            return nil
        end

        local nChildren = 0
        pcall(function()
            if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end
        end)

        for i = 0, math.max(nChildren - 1, 0) do
            local child = nil
            pcall(function() child = WidgetObj:GetChildAt(i) end)
            if child and slua.isValid(child) then
                local result = PlayerMapMarker.FindWeaponIconInWidget(child, Depth + 1, MaxDepth)
                if result then return result end
            end
        end

        if nChildren == 0 then
            local Root = PlayerMapMarker._GetWidgetRoot(WidgetObj)
            if Root and slua.isValid(Root) and Root ~= WidgetObj then
                local result = PlayerMapMarker.FindWeaponIconInWidget(Root, Depth + 1, MaxDepth)
                if result then return result end
            end
        end

        return nil
    end

    function PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, DefaultW, DefaultH)
        if not ImageWidget or not slua.isValid(ImageWidget) then return end
        
        DefaultW = DefaultW or 138
        DefaultH = DefaultH or 69
        
        pcall(function()
            local brush = ImageWidget.Brush
            if brush then
                brush.ImageSize = FVector2D(DefaultW, DefaultH)
                brush.DrawAs = 3
                brush.TintColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                if ImageWidget.SetBrush then
                    ImageWidget:SetBrush(brush)
                end
            end
            
            if ImageWidget.SetDesiredSizeOverride then
                ImageWidget:SetDesiredSizeOverride(FVector2D(DefaultW, DefaultH))
            end
            
            local slot = ImageWidget.Slot
            if slot and slot.SetSize then
                slot:SetSize(FVector2D(DefaultW, DefaultH))
            end
            
            ImageWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            ImageWidget:SetRenderOpacity(1.0)
            ImageWidget:SetColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
        end)
    end

    function PlayerMapMarker.ApplyWeaponIconFullOpacity(Container, ourWeaponIcon)
        local fullIcon = FLinearColor(1.0, 1.0, 1.0, 1.0)

        if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then return end

        pcall(function()
            if ourWeaponIcon.SetRenderOpacity then ourWeaponIcon:SetRenderOpacity(1.0) end
        end)
        pcall(function()
            if ourWeaponIcon.SetColorAndOpacity then ourWeaponIcon:SetColorAndOpacity(fullIcon) end
        end)
        pcall(function()
            if ourWeaponIcon.SetBrushTintColor then ourWeaponIcon:SetBrushTintColor(fullIcon) end
        end)
        pcall(function()
            if ourWeaponIcon.SetTintColorAndOpacity then ourWeaponIcon:SetTintColorAndOpacity(fullIcon) end
        end)
        
        pcall(function()
            local brush = ourWeaponIcon.Brush
            if brush then
                pcall(function() brush.TintColor = fullIcon end)
                if ourWeaponIcon.SetBrush then ourWeaponIcon:SetBrush(brush) end
            end
        end)

        local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon",
            "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
        for _, pname in ipairs(chainNames) do
            pcall(function()
                local node = Container and Container[pname]
                if node and slua.isValid(node) and node.SetRenderOpacity then
                    node:SetRenderOpacity(1.0)
                end
                if node and slua.isValid(node) and node.SetColorAndOpacity then
                    node:SetColorAndOpacity(fullIcon)
                end
            end)
        end
    end

    function PlayerMapMarker.ApplyWeaponIconToImage(ImageWidget, winfo)
        if not ImageWidget or not slua.isValid(ImageWidget) then
            return false, "no_widget"
        end
        if not winfo or not winfo.WeaponID then
            return false, "no_weapon_id"
        end

        local iconPath = nil
        local method = "none"
        local bHasAddKnownMissing = false
        local defaultW = 138
        local defaultH = 69

        pcall(function()
            local itemRecord = CDataTable.GetTableData("Item", winfo.WeaponID)
            if itemRecord and itemRecord.KillWhiteIcon and itemRecord.KillWhiteIcon ~= "" then
                iconPath = itemRecord.KillWhiteIcon
                method = "KillWhiteIcon"
            end

            if (not iconPath or iconPath == "") and winfo.WeaponIconPath and winfo.WeaponIconPath ~= "" then
                iconPath = winfo.WeaponIconPath
                method = "WeaponIconPath"
            end

            if (not iconPath or iconPath == "") and winfo.WeaponIconTexture and slua.isValid(winfo.WeaponIconTexture) then
                if ImageWidget.SetBrushFromTexture then
                    ImageWidget:SetBrushFromTexture(winfo.WeaponIconTexture, true)
                    method = "WeaponIconTexture"
                    return
                end
            end

            if not iconPath or iconPath == "" then
                local UIUtil = require("client.common.ui_util")
                iconPath, bHasAddKnownMissing = UIUtil.GetItemBigIcon(winfo.WeaponID, ImageWidget)
                if iconPath and iconPath ~= "" then
                    method = "GetItemBigIcon"
                end
            end

            if not iconPath or iconPath == "" then
                local UIUtil = require("client.common.ui_util")
                iconPath = UIUtil.GetItemSmallIcon(winfo.WeaponID, ImageWidget, bHasAddKnownMissing)
                if iconPath and iconPath ~= "" then
                    method = "GetItemSmallIcon"
                end
            end
        end)

        if method == "WeaponIconTexture" then
            PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, defaultW, defaultH)
            return true, method
        end
        
        if not iconPath or iconPath == "" then
            return false, "no_path"
        end

        local bOK = false
        pcall(function()
            if ImageWidget.SetBrushResourceFromPathSync then
                ImageWidget:SetBrushResourceFromPathSync(iconPath, true)
                bOK = true
            end
            
            if not bOK then
                local util = require("client.slua_ui_framework.util")
                local result = util.SetTexture(ImageWidget, iconPath, {
                    sync = true,
                    bMatchSize = true,
                    bIsInCombatState = true,
                    bHasAddKnownMissing = bHasAddKnownMissing,
                })
                bOK = result ~= nil
            end
            
            if not bOK then
                local tex = import(iconPath)
                if tex and slua.isValid(tex) and ImageWidget.SetBrushFromTexture then
                    ImageWidget:SetBrushFromTexture(tex, true)
                    bOK = true
                end
            end
            
            if not bOK then
                local LoadObject = import("LoadObject")
                if LoadObject then
                    local tex = LoadObject(iconPath)
                    if tex and slua.isValid(tex) and ImageWidget.SetBrushFromTexture then
                        ImageWidget:SetBrushFromTexture(tex, true)
                        bOK = true
                    end
                end
            end
        end)

        if bOK then
            PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, defaultW, defaultH)
        end

        return bOK, method .. ":" .. tostring(iconPath)
    end

    function PlayerMapMarker.CopyWeaponIconBrushFromNative(ourWeaponIcon, nativeWeaponIcon)
        if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then return false end
        if not nativeWeaponIcon or not slua.isValid(nativeWeaponIcon) then return false end

        local bCopied = false
        
        pcall(function()
            local nBrush = nativeWeaponIcon.Brush
            if nBrush then
                local resObj = nil
                pcall(function() resObj = nBrush.ResourceObject end)
                if resObj and slua.isValid(resObj) and ourWeaponIcon.SetBrushFromTexture then
                    ourWeaponIcon:SetBrushFromTexture(resObj, true)
                    bCopied = true
                end
                
                if bCopied then
                    local imgSize = nil
                    pcall(function() imgSize = nBrush.ImageSize end)
                    if imgSize then
                        local oBrush = ourWeaponIcon.Brush
                        if oBrush then
                            oBrush.ImageSize = imgSize
                            if ourWeaponIcon.SetBrush then
                                ourWeaponIcon:SetBrush(oBrush)
                            end
                        end
                    end
                end
            end
        end)

        return bCopied
    end

    function PlayerMapMarker.AddWeaponIconToESP(WidgetData, Character)
        if not WidgetData or not WidgetData.Container then return end
        local Container = WidgetData.Container
        if not slua.isValid(Container) then return end

        pcall(function()
            local ourWeaponIcon = Container.WeaponIcon
            if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then
                ourWeaponIcon = PlayerMapMarker.FindWeaponIconInWidget(Container, 0, 8)
            end

            if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then
                return
            end

            local winfo = Character and PlayerMapMarker.GetCharacterWeaponInfo(Character) or nil

            if not winfo or not winfo.WeaponID or winfo.WeaponID == 0 then
                pcall(function() ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon",
                    "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
                for _, pname in ipairs(chainNames) do
                    pcall(function()
                        local node = Container and Container[pname]
                        if node and slua.isValid(node) and node.SetWidgetVisibility then
                            node:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        end
                    end)
                end
                WidgetData._LastWeaponID = 0
                WidgetData._WeaponIconApplied = false
                return
            end

            if WidgetData._LastWeaponID == winfo.WeaponID and WidgetData._WeaponIconApplied then
                pcall(function() ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                pcall(function() ourWeaponIcon:SetRenderOpacity(1.0) end)
                local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon",
                    "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
                for _, pname in ipairs(chainNames) do
                    pcall(function()
                        local node = Container and Container[pname]
                        if node and slua.isValid(node) and node.SetWidgetVisibility then
                            node:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                            pcall(function() if node.SetRenderOpacity then node:SetRenderOpacity(1.0) end end)
                        end
                    end)
                end
                if WidgetData._CachedSwitcherIndexes then
                    for sName, idx in pairs(WidgetData._CachedSwitcherIndexes) do
                        pcall(function()
                            local ws = Container[sName]
                            if ws and slua.isValid(ws) and ws.SetActiveWidgetIndex then
                                ws:SetActiveWidgetIndex(idx)
                            end
                        end)
                    end
                end
                if WidgetData._CachedParentSwitchers then
                    for _, data in pairs(WidgetData._CachedParentSwitchers) do
                        pcall(function()
                            if data.w and slua.isValid(data.w) and data.w.SetActiveWidgetIndex then
                                data.w:SetActiveWidgetIndex(data.idx)
                            end
                        end)
                    end
                end
                return
            end

            local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon",
                "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
            for _, pname in ipairs(chainNames) do
                pcall(function()
                    local node = Container and Container[pname]
                    if node and slua.isValid(node) and node.SetWidgetVisibility then
                        node:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    end
                end)
            end

            local bCopied = false
            local copyMethod = "none"
            if winfo and winfo.WeaponID then
                local ok, method = PlayerMapMarker.ApplyWeaponIconToImage(ourWeaponIcon, winfo)
                if ok then
                    bCopied = true
                    copyMethod = method
                end
            end

            local bWeaponIconSet = false
            if Character and winfo then
                if winfo and winfo.WeaponID then
                    pcall(function()
                        if Container.SetWeaponIcon then
                            Container:SetWeaponIcon(winfo.WeaponID)
                            bWeaponIconSet = true
                        end
                    end)
                    if not bWeaponIconSet then
                        pcall(function()
                            if Container.SetWeaponIconByID then
                                Container:SetWeaponIconByID(winfo.WeaponID)
                                bWeaponIconSet = true
                            end
                        end)
                    end
                    if not bWeaponIconSet then
                        pcall(function()
                            if Container.UpdateWeaponIcon then
                                Container:UpdateWeaponIcon(winfo.WeaponID)
                                bWeaponIconSet = true
                            end
                        end)
                    end
                    if not bWeaponIconSet then
                        pcall(function()
                            if Container.SetWeaponID then
                                Container:SetWeaponID(winfo.WeaponID)
                                bWeaponIconSet = true
                            end
                        end)
                    end
                    pcall(function()
                        if Container.SetData then
                            Container:SetData(Character)
                        end
                    end)
                    pcall(function()
                        if Container.SetObservedPlayer then
                            Container:SetObservedPlayer(Character)
                        end
                    end)
                    pcall(function()
                        if Container.SetPlayerInfo then
                            Container:SetPlayerInfo(Character)
                        end
                    end)
                    if winfo.CurrentWeapon then
                        pcall(function()
                            if Container.SetCurrentWeapon then
                                Container:SetCurrentWeapon(winfo.CurrentWeapon)
                            end
                        end)
                    end
                end
            end

            if bWeaponIconSet then
                pcall(function()
                    local innerIcon = Container.Image_Icon
                    if not innerIcon or not slua.isValid(innerIcon) then
                        if Container.CanvasPanel_Type1 then
                            innerIcon = Container.CanvasPanel_Type1.Image_Icon
                        end
                    end
                    if not innerIcon or not slua.isValid(innerIcon) then
                        local function findImageIcon(w, depth)
                            if not w or not slua.isValid(w) or depth > 8 then return nil end
                            local prop = w.Image_Icon
                            if prop and slua.isValid(prop) then return prop end
                            local n = 0
                            pcall(function() if w.GetChildrenCount then n = w:GetChildrenCount() end end)
                            for i = 0, math.max(n - 1, 0) do
                                local c = nil
                                pcall(function() c = w:GetChildAt(i) end)
                                if c then
                                    local r = findImageIcon(c, depth + 1)
                                    if r then return r end
                                end
                            end
                            return nil
                        end
                        innerIcon = findImageIcon(Container, 0)
                    end
                    if innerIcon and slua.isValid(innerIcon) and innerIcon ~= ourWeaponIcon then
                        pcall(function()
                            local ibrush = innerIcon.Brush
                            if ibrush then
                                local iresObj = nil
                                pcall(function() iresObj = ibrush.ResourceObject end)
                                if iresObj and slua.isValid(iresObj) then
                                    if ourWeaponIcon.SetBrushFromAsset then
                                        ourWeaponIcon:SetBrushFromAsset(iresObj)
                                        bCopied = true
                                        copyMethod = "SetWeaponIcon+Image_Icon->SetBrushFromAsset"
                                    end
                                    if not bCopied and ourWeaponIcon.SetBrushFromTexture then
                                        ourWeaponIcon:SetBrushFromTexture(iresObj)
                                        bCopied = true
                                        copyMethod = "SetWeaponIcon+Image_Icon->SetBrushFromTexture"
                                    end
                                end
                            end
                        end)
                        if not bCopied then
                            pcall(function()
                                local brush = innerIcon.Brush
                                if brush then
                                    local iresObj = nil
                                    pcall(function() iresObj = brush.ResourceObject end)
                                    if iresObj and slua.isValid(iresObj) and ourWeaponIcon.SetBrushFromTexture then
                                        ourWeaponIcon:SetBrushFromTexture(iresObj, false)
                                        PlayerMapMarker.FixWeaponIconBrushSize(ourWeaponIcon)
                                        bCopied = true
                                        copyMethod = "SetWeaponIcon+Image_Icon->SetBrushFromTexture"
                                    end
                                end
                            end)
                        end
                    end
                end)
            end

            if not bCopied then
                local nativeWeaponIcon = nil
                if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
                    local nChildren = 0
                    pcall(function() nChildren = PlayerMapMarker.ESPCanvas:GetChildrenCount() end)
                    for i = 0, math.max(nChildren - 1, 0) do
                        local child = nil
                        pcall(function() child = PlayerMapMarker.ESPCanvas:GetChildAt(i) end)
                        if child and slua.isValid(child) then
                            local cstr = tostring(child)
                            if string.find(cstr, "OB_PlayerHeadHPItem") then
                                if not PlayerMapMarker.IsOurESPWidget(child) then
                                    local nativeIcon = child.WeaponIcon
                                    if nativeIcon and slua.isValid(nativeIcon) then
                                        nativeWeaponIcon = nativeIcon
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                if nativeWeaponIcon and slua.isValid(nativeWeaponIcon) then
                    local okNative, nativeMethod = PlayerMapMarker.CopyWeaponIconBrushFromNative(ourWeaponIcon, nativeWeaponIcon)
                    if okNative then
                        bCopied = true
                        copyMethod = nativeMethod
                    end
                end
            end

            if not bCopied then
                pcall(function()
                    local brush = ourWeaponIcon.Brush
                    if brush then
                        local resObj = nil
                        pcall(function() resObj = brush.ResourceObject end)
                        if resObj and slua.isValid(resObj) and ourWeaponIcon.SetBrushFromTexture then
                            ourWeaponIcon:SetBrushFromTexture(resObj)
                            bCopied = true
                            copyMethod = "ReRegisterDefault:SetBrushFromTexture"
                        end
                    end
                end)
            end

            if not bCopied then
                pcall(function()
                    local brush = ourWeaponIcon.Brush
                    if brush then
                        local imgSize = nil
                        pcall(function() imgSize = brush.ImageSize end)
                        local bZeroSize = false
                        if imgSize then
                            local sx, sy = nil, nil
                            pcall(function() sx = imgSize.X end)
                            pcall(function() sy = imgSize.Y end)
                            if (not sx or sx == 0) and (not sy or sy == 0) then
                                bZeroSize = true
                            end
                        end
                        if bZeroSize then
                            pcall(function()
                                brush.ImageSize = FVector2D(
                                    PlayerMapMarker.WeaponIconBrushW or 138,
                                    PlayerMapMarker.WeaponIconBrushH or 69)
                            end)
                        end
                        pcall(function() brush.DrawAs = 3 end)
                        if ourWeaponIcon.SetBrush then
                            ourWeaponIcon:SetBrush(brush)
                        end
                    end
                end)
            end

            pcall(function() ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            PlayerMapMarker.ApplyWeaponIconFullOpacity(Container, ourWeaponIcon)
            PlayerMapMarker.FixWeaponIconBrushSize(ourWeaponIcon)

            pcall(function()
                local function findWidgetInSwitcher(switcher, targetWidget)
                    if not switcher or not slua.isValid(switcher) then return nil end
                    if not switcher.GetChildrenCount or not switcher.GetChildAt then return nil end
                    local nChildren = switcher:GetChildrenCount()
                    for i = 0, math.max(nChildren - 1, 0) do
                        local child = switcher:GetChildAt(i)
                        if child and slua.isValid(child) then
                            if child == targetWidget then return i end
                            local function searchDescendant(w, target, depth)
                                if depth > 5 then return false end
                                if w == target then return true end
                                if not w.GetChildrenCount or not w.GetChildAt then return false end
                                local nc = w:GetChildrenCount()
                                for j = 0, math.max(nc - 1, 0) do
                                    local c = w:GetChildAt(j)
                                    if c and slua.isValid(c) and searchDescendant(c, target, depth + 1) then
                                        return true
                                    end
                                end
                                return false
                            end
                            if searchDescendant(child, targetWidget, 0) then return i end
                        end
                    end
                    return nil
                end

                for _, switcherName in ipairs({"Switcher_WeaponIcon", "WidgetSwitcher_Type", "WidgetSwitcher_Type2"}) do
                    local ws = Container[switcherName]
                    if ws and slua.isValid(ws) and ws.GetChildrenCount and ws.GetChildAt then
                        local foundIdx = findWidgetInSwitcher(ws, ourWeaponIcon)
                        if foundIdx then
                            if ws.SetActiveWidgetIndex then
                                ws:SetActiveWidgetIndex(foundIdx)
                                WidgetData._CachedSwitcherIndexes = WidgetData._CachedSwitcherIndexes or {}
                                WidgetData._CachedSwitcherIndexes[switcherName] = foundIdx
                            end
                        end
                    end
                end
            end)

            pcall(function()
                local parent = ourWeaponIcon
                for depth = 0, 8 do
                    if not parent or not slua.isValid(parent) then break end
                    if parent.GetParent then
                        local p = parent:GetParent()
                        if p and slua.isValid(p) then
                            local pStr = tostring(p)
                            if string.find(pStr, "WidgetSwitcher") then
                                if p.GetChildrenCount and p.GetChildAt then
                                    local nCh = p:GetChildrenCount()
                                    for i = 0, math.max(nCh - 1, 0) do
                                        local child = p:GetChildAt(i)
                                        if child and slua.isValid(child) then
                                            local function isDescendant(w, target, d)
                                                if d > 5 then return false end
                                                if w == target then return true end
                                                if not w.GetChildrenCount or not w.GetChildAt then return false end
                                                local nc = w:GetChildrenCount()
                                                for j = 0, math.max(nc - 1, 0) do
                                                    local c = w:GetChildAt(j)
                                                    if c and slua.isValid(c) and isDescendant(c, target, d + 1) then
                                                        return true
                                                    end
                                                end
                                                return false
                                            end
                                            if isDescendant(child, ourWeaponIcon, 0) then
                                                if p.SetActiveWidgetIndex then
                                                    p:SetActiveWidgetIndex(i)
                                                    WidgetData._CachedParentSwitchers = WidgetData._CachedParentSwitchers or {}
                                                    WidgetData._CachedParentSwitchers[tostring(p)] = {w = p, idx = i}
                                                end
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            parent = p
                        else
                            break
                        end
                    else
                        break
                    end
                end
            end)

            pcall(function()
                local parent = ourWeaponIcon
                for depth = 0, 8 do
                    pcall(function()
                        if parent.GetParent then
                            local p = parent:GetParent()
                            if p and slua.isValid(p) then
                                if p.SetWidgetVisibility then
                                    p:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                end
                                pcall(function() if p.SetRenderOpacity then p:SetRenderOpacity(1.0) end end)
                                pcall(function() if p.SetContentColorAndOpacity then p:SetContentColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0)) end end)
                                pcall(function() if p.SetColorAndOpacity then p:SetColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0)) end end)
                                pcall(function() if p.SetBrushTintColor then p:SetBrushTintColor(FLinearColor(1.0, 1.0, 1.0, 1.0)) end end)
                                pcall(function()
                                    local pBrush = p.Brush
                                    if pBrush and pBrush.TintColor then
                                        pBrush.TintColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                                        if p.SetBrush then p:SetBrush(pBrush) end
                                    end
                                end)
                                pcall(function() if p.InvalidateLayout then p:InvalidateLayout() end end)
                                parent = p
                            end
                        end
                    end)
                end
            end)
            pcall(function() if ourWeaponIcon.InvalidateLayout then ourWeaponIcon:InvalidateLayout() end end)

            pcall(function() if Container.UpdateWeapon then Container:UpdateWeapon() end end)
            pcall(function() if Container.RefreshWeapon then Container:RefreshWeapon() end end)
            
            WidgetData._LastWeaponID = winfo.WeaponID
            WidgetData._WeaponIconApplied = true
        end)
    end

    PlayerMapMarker._OBHeadWidgetClass = nil
    PlayerMapMarker._OBHeadWidgetLoadFailed = false
    PlayerMapMarker._bDumpedWidgetChildren = false

    function PlayerMapMarker.CreateESPWidget()
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
            return nil
        end

        if PlayerMapMarker._OBHeadWidgetLoadFailed then
            return nil
        end

        if not PlayerMapMarker._OBHeadWidgetClass then
            pcall(function()
                local Path = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP"
                local uClass = slua.loadClass(Path)
                if uClass then
                    PlayerMapMarker._OBHeadWidgetClass = uClass
                end
            end)
            if not PlayerMapMarker._OBHeadWidgetClass then
                PlayerMapMarker._OBHeadWidgetLoadFailed = true
                return nil
            end
        else
            local bValid = false
            pcall(function() bValid = slua.isValid(PlayerMapMarker._OBHeadWidgetClass) end)
            if not bValid then
                PlayerMapMarker._OBHeadWidgetLoadFailed = true
                PlayerMapMarker._OBHeadWidgetClass = nil
                return nil
            end
        end

        local Widget = nil
        pcall(function()
            local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
            local PC = PlayerMapMarker.GetMyPlayerController()
            local OuterObj = IsValid(PC) and PC.Object or PlayerMapMarker.ESPCanvas
            Widget = STExtraBlueprintFunctionLibrary.CreateWidgetByClass(PlayerMapMarker._OBHeadWidgetClass, OuterObj)
        end)

        if not Widget then
            return nil
        end

        pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function() Widget:SetRenderOpacity(1.0) end)

        local NameText = nil
        local HealthFill = nil
        local bIsOriginalProgressBar = false

        pcall(function()
            NameText = Widget.TextBlock_TeamName
            if NameText and slua.isValid(NameText) then
                pcall(function() NameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            end
            if Widget.TextBlock_PlayerName and slua.isValid(Widget.TextBlock_PlayerName) then
                pcall(function() Widget.TextBlock_PlayerName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            end

            local WS_Type = Widget.WidgetSwitcher_Type
            local WS_Type2 = Widget.WidgetSwitcher_Type2
            if WS_Type and slua.isValid(WS_Type) then
                pcall(function()
                    if WS_Type.SetActiveWidgetIndex then
                        WS_Type:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherTypeIndex)
                    end
                end)
            end
            if WS_Type2 and slua.isValid(WS_Type2) then
                pcall(function()
                    if WS_Type2.SetActiveWidgetIndex then
                        WS_Type2:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherType2Index)
                    end
                end)
            end

            local SizeBox_HP = Widget.SizeBox_HP
            if SizeBox_HP and slua.isValid(SizeBox_HP) then
                pcall(function() SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                pcall(function() SizeBox_HP:SetHeightOverride(6) end)
                pcall(function() SizeBox_HP:SetWidthOverride(100) end)

                local ExistingChild = nil
                pcall(function()
                    if SizeBox_HP.GetContent then
                        ExistingChild = SizeBox_HP:GetContent()
                    end
                end)
                if not ExistingChild then
                    pcall(function()
                        if SizeBox_HP.GetChildAt then
                            ExistingChild = SizeBox_HP:GetChildAt(0)
                        end
                    end)
                end

                if ExistingChild and slua.isValid(ExistingChild) then
                    pcall(function() ExistingChild:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                    pcall(function() ExistingChild:SetRenderOpacity(1.0) end)

                    local FoundPB = PlayerMapMarker.FindProgressBarInWidget(ExistingChild, 0, 5)
                    if FoundPB and slua.isValid(FoundPB) then
                        HealthFill = FoundPB
                        bIsOriginalProgressBar = true
                        pcall(function() FoundPB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        pcall(function() FoundPB:SetRenderOpacity(1.0) end)
                    else
                        local PB = CGame:NewObjectFromPath("/Script/UMG.ProgressBar", ExistingChild)
                        if PB then
                            pcall(function() PB:SetFillColorAndOpacity(FLinearColor(0, 1, 0, 1)) end)
                            pcall(function() PB:SetPercent(1.0) end)
                            pcall(function() PB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                            pcall(function() PB:SetRenderOpacity(1.0) end)
                            pcall(function() PB:SetDesiredSizeOverride(FVector2D(100, 6)) end)
                            pcall(function() ExistingChild:AddChild(PB) end)
                            HealthFill = PB
                        end
                    end
                else
                    local PB = CGame:NewObjectFromPath("/Script/UMG.ProgressBar", SizeBox_HP)
                    if PB then
                        pcall(function() PB:SetFillColorAndOpacity(FLinearColor(0, 1, 0, 1)) end)
                        pcall(function() PB:SetPercent(1.0) end)
                        pcall(function() PB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        pcall(function() PB:SetRenderOpacity(1.0) end)
                        pcall(function() PB:SetDesiredSizeOverride(FVector2D(100, 6)) end)

                        local bUsedSetContent = false
                        pcall(function()
                            if SizeBox_HP.SetContent then
                                SizeBox_HP:SetContent(PB)
                                bUsedSetContent = true
                            end
                        end)
                        if not bUsedSetContent then
                            pcall(function() SizeBox_HP:AddChild(PB) end)
                        end
                        HealthFill = PB
                    end
                end
            end
        end)

        local WidgetData = {
            Container = Widget,
            NameText = NameText,
            HealthFill = HealthFill,
            IsGameWidget = true,
            IsOriginalProgressBar = bIsOriginalProgressBar,
            HasChildren = (NameText ~= nil)
        }
        return WidgetData
    end

    PlayerMapMarker._CanvasScaleX = 1.0
    PlayerMapMarker._CanvasScaleY = 1.0
    PlayerMapMarker._CanvasOffsetX = 0.0
    PlayerMapMarker._CanvasOffsetY = 0.0

    function PlayerMapMarker.UpdateCanvasTransform(PC)
        local now = os.time()
        if PlayerMapMarker._CanvasTransformTime and (now - PlayerMapMarker._CanvasTransformTime) < 1 then
            return
        end
        PlayerMapMarker._CanvasTransformTime = now

        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
            return
        end

        local success = false

        pcall(function()
            local SBL = SlateBlueprintLibrary
            if SBL and SBL.AbsoluteToLocal then
                local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
                if cg then
                    local pt0 = SBL.AbsoluteToLocal(cg, FVector2D(0, 0))
                    local pt1 = SBL.AbsoluteToLocal(cg, FVector2D(100, 100))
                    if pt0 and pt1 then
                        PlayerMapMarker._CanvasScaleX = (pt1.X - pt0.X) / 100
                        PlayerMapMarker._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                        PlayerMapMarker._CanvasOffsetX = pt0.X
                        PlayerMapMarker._CanvasOffsetY = pt0.Y
                        success = true
                    end
                end
            end
        end)

        if not success then
            pcall(function()
                local WLL = WidgetLayoutLibrary
                if WLL and WLL.ScreenToWidgetLocal then
                    local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
                    if cg then
                        local pt0 = FVector2D(0, 0)
                        local pt1 = FVector2D(0, 0)
                        WLL.ScreenToWidgetLocal(PC, cg, FVector2D(0, 0), pt0)
                        WLL.ScreenToWidgetLocal(PC, cg, FVector2D(100, 100), pt1)
                        PlayerMapMarker._CanvasScaleX = (pt1.X - pt0.X) / 100
                        PlayerMapMarker._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                        PlayerMapMarker._CanvasOffsetX = pt0.X
                        PlayerMapMarker._CanvasOffsetY = pt0.Y
                        success = true
                    end
                end
            end)
        end

        if not success then
            local scale = 1.0
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportScale then
                scale = WLL.GetViewportScale(PC) or 1.0
            end
            PlayerMapMarker._CanvasScaleX = 1.0 / scale
            PlayerMapMarker._CanvasScaleY = 1.0 / scale
            PlayerMapMarker._CanvasOffsetX = 0
            PlayerMapMarker._CanvasOffsetY = 0
        end
    end

    function PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
        if not ScreenPixelPos then return FVector2D(0, 0) end
        local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
        local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
        local offsetX = PlayerMapMarker._CanvasOffsetX or 0
        local offsetY = PlayerMapMarker._CanvasOffsetY or 0
        ReuseCanvasLocal.X = ScreenPixelPos.X * scaleX + offsetX
        ReuseCanvasLocal.Y = ScreenPixelPos.Y * scaleY + offsetY
        return ReuseCanvasLocal
    end

    function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
        if not IsValid(PC) or not WorldLoc then return false, ReuseCanvasLocal end

        ReuseScreenPixel.X = 0
        ReuseScreenPixel.Y = 0
        local bOK = false

        pcall(function()
            local res = PC:ProjectWorldLocationToScreen(WorldLoc, ReuseScreenPixel, true)
            if res == true or res == 1 or (ReuseScreenPixel.X ~= 0 or ReuseScreenPixel.Y ~= 0) then
                bOK = true
            end
        end)

        if not bOK or (ReuseScreenPixel.X == 0 and ReuseScreenPixel.Y == 0) then
            return false, ReuseCanvasLocal
        end

        local CanvasLocalPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ReuseScreenPixel)
        return true, CanvasLocalPos
    end

    function PlayerMapMarker.GetDynamicViewportSize(PC)
        local width, height = 0, 0
        
        if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
            pcall(function()
                local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
                if cg and cg.GetLocalSize then
                    local sz = cg:GetLocalSize()
                    if sz and sz.X and sz.X > 200 then
                        width = sz.X
                        height = sz.Y
                    end
                end
            end)
        end

        if width > 200 then return width, height end

        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportSize then
                local sz = WLL.GetViewportSize(PC or PlayerMapMarker.GetMyPlayerController())
                if sz and sz.X and sz.X > 200 then
                    width = sz.X
                    height = sz.Y
                end
            end
        end)

        if width > 200 then
            pcall(function()
                local WLL = WidgetLayoutLibrary
                if WLL and WLL.GetViewportScale then
                    local scale = WLL.GetViewportScale(PC or PlayerMapMarker.GetMyPlayerController())
                    if scale and type(scale) == "number" and scale > 0 and scale ~= 1.0 then
                        width = width / scale
                        height = height / scale
                    end
                end
            end)
            return width, height
        end

        return PlayerMapMarker._cachedViewportW or 1920, PlayerMapMarker._cachedViewportH or 1080
    end

    function PlayerMapMarker.UpdateESPPositionWithPC(Widget, WorldLoc, PC, CanvasPos)
        if not Widget or not IsValid(PC) then return false end
        local Container = Widget.Container or Widget

        local bOnScreen = true
        if not CanvasPos then
            if not WorldLoc then return false end
            bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
        end

        if not bOnScreen then
            pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            return false
        end

        pcall(function()
            if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
                local ptr = tostring(Container)
                local Slot = PlayerMapMarker.ESPWidgetPtrs[ptr]

                if not Slot or not slua.isValid(Slot) or type(Slot) == "boolean" then
                    local addedSlot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Container)
                    if addedSlot and slua.isValid(addedSlot) then
                        Slot = addedSlot
                        PlayerMapMarker.ESPWidgetPtrs[ptr] = addedSlot
                        if type(Widget) == "table" then
                            Widget.Slot = addedSlot
                        end
                        
                        pcall(function() Slot:SetAutoSize(true) end)
                        pcall(function() Slot.bAutoSize = true end)
                        local align = FVector2D(0.5, 1.0)
                        pcall(function() Slot.Alignment = align end)
                        pcall(function() Slot:SetAlignment(align) end)
                        pcall(function() Slot:SetAlignment(0.5, 1.0) end)
                        pcall(function() Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 20) end)
                    end
                end

                Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                
                if not Widget._OffsetResetDone then
                    pcall(function() Container:SetRenderTranslation(FVector2D(0.0, 0.0)) end)
                    if Widget and type(Widget) == "table" then
                        if Widget.NameText and slua.isValid(Widget.NameText) then
                            pcall(function() Widget.NameText:SetRenderTranslation(FVector2D(0.0, 0.0)) end)
                        end
                        if Widget.HealthFill and slua.isValid(Widget.HealthFill) then
                            pcall(function() Widget.HealthFill:SetRenderTranslation(FVector2D(0.0, 0.0)) end)
                        end
                    end
                    
                    pcall(function() Container.RenderTransformPivot = FVector2D(0.5, 1.0) end)
                    pcall(function() Container:SetRenderTransformPivot(FVector2D(0.5, 1.0)) end)
                    Widget._OffsetResetDone = true
                end

                if not Slot or not slua.isValid(Slot) or Slot == PlayerMapMarker.ESPCanvas then
                    if Widget and type(Widget) == "table" and Widget.Slot and slua.isValid(Widget.Slot) then
                        Slot = Widget.Slot
                    elseif Container.Slot and slua.isValid(Container.Slot) then
                        Slot = Container.Slot
                    end
                end

                if Slot and slua.isValid(Slot) and Slot ~= PlayerMapMarker.ESPCanvas then
                    local finalX = CanvasPos.X + (PlayerMapMarker.ESPAnchorOffsetX or 0)
                    local finalY = CanvasPos.Y + (PlayerMapMarker.ESPAnchorOffsetY or 0)
                    if Widget and type(Widget) == "table" then
                        if not Widget._CachedPosVec then
                            Widget._CachedPosVec = FVector2D(finalX, finalY)
                        else
                            Widget._CachedPosVec.X = finalX
                            Widget._CachedPosVec.Y = finalY
                        end
                        pcall(function() Slot:SetPosition(Widget._CachedPosVec) end)
                    else
                        pcall(function() Slot:SetPosition(FVector2D(finalX, finalY)) end)
                    end
                end
            end
        end)
        return true
    end

    function PlayerMapMarker.UpdateESPText(Widget, Text)
        if not Widget then return end
        if Widget._LastESPText == Text then return end
        Widget._LastESPText = Text

        local function applyTextAndCenter(w, txt)
            if not w or not slua.isValid(w) then return end
            pcall(function() w:SetText(txt) end)
            pcall(function() if w.SetJustification then w:SetJustification(1) end end)
            pcall(function()
                local slot = w.Slot
                if slot and slot.SetHorizontalAlignment then
                    slot:SetHorizontalAlignment(1)
                end
            end)
            pcall(function()
                w:SetRenderTranslation(FVector2D(PlayerMapMarker.ESPTextOffsetX or 0, PlayerMapMarker.ESPTextOffsetY or 0))
            end)
        end

        if Widget.NameText and slua.isValid(Widget.NameText) then
            applyTextAndCenter(Widget.NameText, Text)
        end
        if Widget.IsGameWidget and Widget.Container then
            pcall(function()
                local W = Widget.Container
                if W and slua.isValid(W) then
                    if W.SetPlayerName then
                        local Name = Text
                        local idx = string.find(Text, " %[")
                        if idx then Name = string.sub(Text, 1, idx - 1) end
                        W:SetPlayerName(Name)
                    end

                    applyTextAndCenter(W.TextBlock_TeamName, Text)
                    applyTextAndCenter(W.TextBlock_PlayerName, Text)

                    pcall(function()
                        if not Widget._CachedVBChildren then
                            local list = {}
                            local VB = PlayerMapMarker._FindNamedWidgetInTree(W, "VerticalBox_0", 8)
                            if VB and slua.isValid(VB) and VB.GetChildrenCount then
                                local nChildren = VB:GetChildrenCount()
                                for i = 0, nChildren - 1 do
                                    local child = VB:GetChildAt(i)
                                    if child and slua.isValid(child) and child.SetText then
                                        table.insert(list, child)
                                    end
                                end
                            end
                            Widget._CachedVBChildren = list
                        end
                        for _, child in ipairs(Widget._CachedVBChildren) do
                            applyTextAndCenter(child, Text)
                        end
                    end)

                    pcall(function()
                        if not Widget._CachedHBChildren then
                            local list = {}
                            local HB = PlayerMapMarker._FindNamedWidgetInTree(W, "HorizontalBox_TeamName", 8)
                            if HB and slua.isValid(HB) and HB.GetChildrenCount then
                                local nChildren = HB:GetChildrenCount()
                                for i = 0, nChildren - 1 do
                                    local child = HB:GetChildAt(i)
                                    if child and slua.isValid(child) and child.SetText then
                                        table.insert(list, child)
                                    end
                                end
                            end
                            Widget._CachedHBChildren = list
                        end
                        for _, child in ipairs(Widget._CachedHBChildren) do
                            applyTextAndCenter(child, Text)
                        end
                    end)
                end
            end)
        end
    end

    function PlayerMapMarker.UpdateESPHealth(Widget, pct)
        if not Widget then return end
        if Widget.LastPct == pct then return end
        Widget.LastPct = pct

        if PlayerMapMarker.bForceSwitcherIndexEveryUpdate and Widget.Container then
            pcall(function()
                local W = Widget.Container
                if W and slua.isValid(W) then
                    if not Widget._SwitcherSetupDone then
                        if W.WidgetSwitcher_Type and slua.isValid(W.WidgetSwitcher_Type) then
                            pcall(function()
                                if W.WidgetSwitcher_Type.SetActiveWidgetIndex then
                                    W.WidgetSwitcher_Type:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherTypeIndex)
                                end
                            end)
                        end
                        if W.WidgetSwitcher_Type2 and slua.isValid(W.WidgetSwitcher_Type2) then
                            pcall(function()
                                if W.WidgetSwitcher_Type2.SetActiveWidgetIndex then
                                    W.WidgetSwitcher_Type2:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherType2Index)
                                end
                            end)
                        end
                        if W.SizeBox_HP and slua.isValid(W.SizeBox_HP) then
                            pcall(function() W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        end
                        Widget._SwitcherSetupDone = true
                    end
                end
            end)
        end

        if Widget.HealthFill then
            local bValid = false
            pcall(function() bValid = slua.isValid(Widget.HealthFill) end)
            if bValid then
                local bHasSetPercent = false
                pcall(function() bHasSetPercent = (Widget.HealthFill.SetPercent ~= nil) end)
                if not bHasSetPercent then
                    local PB = PlayerMapMarker.FindProgressBarInWidget(Widget.HealthFill, 0, 5)
                    if PB and slua.isValid(PB) then
                        Widget.HealthFill = PB
                    else
                        return
                    end
                end

                pcall(function()
                    if Widget.HealthFill.SetWidgetVisibility then
                        Widget.HealthFill:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    end
                    if Widget.HealthFill.SetRenderOpacity then
                        Widget.HealthFill:SetRenderOpacity(1.0)
                    end
                    if Widget.HealthFill.SetPercent then
                        Widget.HealthFill:SetPercent(pct)
                        if not Widget.IsOriginalProgressBar then
                            local color
                            if pct > 0.5 then
                                color = FLinearColor(0, 1, 0, 1)
                            elseif pct > 0.25 then
                                color = FLinearColor(1, 0.8, 0, 1)
                            else
                                color = FLinearColor(1, 0, 0, 1)
                            end
                            if Widget.HealthFill.SetFillColorAndOpacity then
                                Widget.HealthFill:SetFillColorAndOpacity(color)
                            end
                        end
                    end
                end)
            end
            return
        end
    end

    function PlayerMapMarker.RemoveESPWidget(Widget)
        if not Widget then return end
        local Container = Widget.Container or Widget
        pcall(function()
            local ptr = tostring(Container)
            PlayerMapMarker.ESPWidgetPtrs[ptr] = nil
            Container:RemoveFromParent()
            Container:ConditionalBeginDestroy()
        end)
    end

    function PlayerMapMarker.CreateSnapLine()
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end

        local Border = nil
        pcall(function()
            Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas)
        end)
        if not Border or not slua.isValid(Border) then return nil end

        local color = PlayerMapMarker.SnapLineColor or FLinearColor(1.0, 1.0, 1.0, PlayerMapMarker.SnapLineOpacity or 0.7)
        pcall(function() Border:SetBrushColor(color) end)
        pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        
        pcall(function() Border.RenderTransformPivot = FVector2D(0.0, 0.5) end)
        pcall(function() Border:SetRenderTransformPivot(FVector2D(0.0, 0.5)) end)

        local Slot = nil
        pcall(function()
            Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
            if Slot then
                Slot:SetAutoSize(false)
                Slot:SetZOrder(1)
            end
        end)

        return { Widget = Border, Slot = Slot }
    end

    function PlayerMapMarker.GetSnapLineStartPos(PC)
        local screenPixelW, screenPixelH = 0, 0
        local scale = 1.0

        pcall(function()
            if PC and PC.GetViewportSize then
                local vs = FVector2D(0, 0)
                PC:GetViewportSize(vs)
                if vs and vs.X and vs.X > 200 then
                    screenPixelW = vs.X
                    screenPixelH = vs.Y
                end
            end
        end)

        if screenPixelW <= 200 then
            pcall(function()
                local WLL = WidgetLayoutLibrary
                if WLL and WLL.GetViewportSize then
                    local vs = WLL.GetViewportSize(PC)
                    if vs and vs.X and vs.X > 200 then
                        screenPixelW = vs.X
                        screenPixelH = vs.Y
                    end
                end
            end)
        end

        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportScale then
                local s = WLL.GetViewportScale(PC)
                if s and type(s) == "number" and s > 0 then scale = s end
            end
        end)

        if screenPixelW <= 200 then
            screenPixelW = (PlayerMapMarker._cachedViewportW or 1920) * scale
            screenPixelH = (PlayerMapMarker._cachedViewportH or 1080) * scale
        end

        if not PlayerMapMarker._CachedTopCenterPixel then
            PlayerMapMarker._CachedTopCenterPixel = FVector2D(0, 0)
        end
        PlayerMapMarker._CachedTopCenterPixel.X = screenPixelW / 2.0
        PlayerMapMarker._CachedTopCenterPixel.Y = (PlayerMapMarker.SnapLineOriginY or 50) * scale

        local fromCanvasPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, PlayerMapMarker._CachedTopCenterPixel)
        local fromX = fromCanvasPos.X + (PlayerMapMarker.SnapLineOriginOffsetX or 0)
        local fromY = fromCanvasPos.Y

        return fromX, fromY
    end

    PlayerMapMarker._SnapLineVisCache = {}
    PlayerMapMarker._SnapLineVisInterval = 0.1
    PlayerMapMarker._SnapLineIgnoreActors = nil
    PlayerMapMarker.bUseLineVisCheck = true
    PlayerMapMarker.bUseRedBox = true

    function PlayerMapMarker.IsCharacterVisible(Character)
        if not IsValid(Character) then return false end
        local PC = PlayerMapMarker.GetMyPlayerController()
        if not IsValid(PC) then return true end
        local camManager = GameplayStatics.GetPlayerCameraManager(PC, 0)
        if not Valid(camManager) then return true end
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return true end
        local Loc = PlayerMapMarker.GetESPLocation(Character)
        if not Loc then return true end

        if not PlayerMapMarker._SnapLineIgnoreActors then
            pcall(function()
                local pawn = PC.GetPawn and PC:GetPawn() or nil
                if IsValid(pawn) then
                    PlayerMapMarker._SnapLineIgnoreActors = slua.Array and slua.Array(UEnums.EPropertyClass.Object, pawn) or { pawn }
                end
            end)
        end

        return IsBoneVisible(PC, camLoc, Character, Loc, PlayerMapMarker._SnapLineIgnoreActors)
    end

    function PlayerMapMarker.IsCharacterVisibleCached(KeyStr, Character)
        if not PlayerMapMarker.bUseLineVisCheck then return true end
        if not Character or not KeyStr then return true end
        local now = os.clock()
        local c = PlayerMapMarker._SnapLineVisCache[KeyStr]
        if c and (now - c.t) < PlayerMapMarker._SnapLineVisInterval then
            return c.v
        end
        local vis = PlayerMapMarker.IsCharacterVisible(Character)
        PlayerMapMarker._SnapLineVisCache[KeyStr] = { t = now, v = vis }
        return vis
    end

    function PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY, bVisible, bLocked)
        if not PlayerMapMarker.bUseSnapLines then return end
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

        local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]

        if not bOnScreen or not CanvasPos or bVisible == false then
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
            return
        end

        local bIsNew = false
        if not LineData then
            LineData = PlayerMapMarker.CreateSnapLine()
            if not LineData or not LineData.Widget or not LineData.Slot then return end
            PlayerMapMarker.SnapLineWidgets[KeyStr] = LineData
            bIsNew = true
        end

        local Widget = LineData.Widget
        local Slot = LineData.Slot

        -- LOCK INDICATOR: aimbot ka locked target = red line (state change pe hi set)
        local bLockedNow = (bLocked == true) and _G.AimbotConfig and _G.AimbotConfig.Enable
        if LineData._LockedState ~= bLockedNow then
            LineData._LockedState = bLockedNow
            if bLockedNow then
                pcall(function() Widget:SetBrushColor(FLinearColor(1.0, 0.12, 0.12, 0.95)) end)
                pcall(function() Slot:SetZOrder(6) end)
            else
                pcall(function()
                    Widget:SetBrushColor(PlayerMapMarker.SnapLineColor or FLinearColor(1.0, 1.0, 1.0, PlayerMapMarker.SnapLineOpacity or 0.7))
                end)
                pcall(function() Slot:SetZOrder(1) end)
            end
        end

        pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        
        if not LineData._PivotSet then
            pcall(function() Widget.RenderTransformPivot = FVector2D(0.0, 0.5) end)
            pcall(function() Widget:SetRenderTransformPivot(FVector2D(0.0, 0.5)) end)
            LineData._PivotSet = true
        end

        local toX = CanvasPos.X + (PlayerMapMarker.SnapLineHeadOffsetX or 0)
        local toY = CanvasPos.Y + (PlayerMapMarker.SnapLineHeadOffsetY or 0)

        local dx = toX - fromX
        local dy = toY - fromY
        local length = math.sqrt(dx * dx + dy * dy)
        local thickness = PlayerMapMarker.SnapLineThickness or 1.5
        if LineData._LockedState then thickness = thickness + 1.2 end

        local angle_rad = 0
        if math.atan2 then
            angle_rad = math.atan2(dy, dx)
        else
            angle_rad = math.atan(dy, dx)
        end
        local angle = angle_rad * (180.0 / math.pi)

        if not LineData._CachedPosVec then
            LineData._CachedPosVec = FVector2D(fromX, fromY - thickness / 2.0)
            LineData._CachedSizeVec = FVector2D(length, thickness)
        else
            LineData._CachedPosVec.X = fromX
            LineData._CachedPosVec.Y = fromY - thickness / 2.0
            LineData._CachedSizeVec.X = length
            LineData._CachedSizeVec.Y = thickness
        end

        pcall(function() 
            Slot:SetPosition(LineData._CachedPosVec) 
            Slot:SetSize(LineData._CachedSizeVec)
            if bIsNew then
                Slot:SetZOrder(1)
            end
        end)
        pcall(function() Widget:SetRenderAngle(angle) end)
    end

    function PlayerMapMarker.RemoveSnapLine(KeyStr)
        local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function()
                LineData.Widget:RemoveFromParent()
                LineData.Widget:ConditionalBeginDestroy()
            end)
            PlayerMapMarker.SnapLineWidgets[KeyStr] = nil
        end
    end

    function PlayerMapMarker.ClearAllSnapLines()
        for KeyStr, LineData in pairs(PlayerMapMarker.SnapLineWidgets) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function()
                    LineData.Widget:RemoveFromParent()
                    LineData.Widget:ConditionalBeginDestroy()
                end)
            end
        end
        PlayerMapMarker.SnapLineWidgets = {}
        PlayerMapMarker._SnapLineVisCache = {}
        PlayerMapMarker._SnapLineIgnoreActors = nil
    end

    function PlayerMapMarker.ClearAllESP()
        -- ØªÙ†Ø¸ÙŠÙ ÙƒØ§Ø¦Ù†Ø§Øª Ø§Ù„Ù…Ø³ØªØ·ÙŠÙ„ Ù„Ù…Ù†Ø¹ Ø§Ù„ØªØ±Ø§ÙƒÙ… Ø¨ÙŠÙ† Ø§Ù„Ø£Ø¬ÙˆØ§Ù…
        RedBoxOverlay.Stop()

        for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
            PlayerMapMarker.RemoveESPWidget(Data.Widget)
        end
        PlayerMapMarker.ESPWidgets = {}
        PlayerMapMarker.ESPWidgetPtrs = {}
        PlayerMapMarker.ClearAllSnapLines()
        if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
            pcall(function()
                local n = PlayerMapMarker.ESPCanvas:GetChildrenCount()
                for i = n - 1, 0, -1 do
                    local child = PlayerMapMarker.ESPCanvas:GetChildAt(i)
                    if child and slua.isValid(child) then
                        if PlayerMapMarker.IsOurESPWidget(child) then
                            PlayerMapMarker.ESPCanvas:RemoveChild(child)
                        end
                    end
                end
            end)
        end
        PlayerMapMarker.ESPCanvas = nil
        PlayerMapMarker._OBHeadWidgetClass = nil
        PlayerMapMarker._OBHeadWidgetLoadFailed = false
        PlayerMapMarker._bDumpedWidgetChildren = false
        PlayerMapMarker._cachedViewportW = 1920
        PlayerMapMarker._cachedViewportH = 1080
    end

    function PlayerMapMarker.UpdateESP(AllPlayers, MyLoc)
        if not PlayerMapMarker.bUseScreenESP then return end

        if not PlayerMapMarker.InitESPCanvas() then
            return
        end

        if PlayerMapMarker._OBHeadWidgetLoadFailed then return end

        local PC = PlayerMapMarker.GetMyPlayerController()
        if IsValid(PC) then
            PlayerMapMarker.UpdateCanvasTransform(PC)
        end

        local fromX, fromY = 0, 0
        if PlayerMapMarker.bUseSnapLines and IsValid(PC) then
            fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
        end

        local MyKey = PlayerMapMarker.GetMyPlayerKey()
        local SeenKeys = {}
        local newBudget = PlayerMapMarker._ESPWidgetBudget or 6
        local newMade = 0
        
        local MyChar = nil
        pcall(function()
            local GDP = PlayerMapMarker.GetGameplayData()
            if GDP and GDP.GetLocalCharacter then
                MyChar = GDP.GetLocalCharacter()
            else
                if PC and PC.GetPawn then MyChar = PC:GetPawn() end
            end
        end)
        local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)

        for PlayerKey, Character in pairs(AllPlayers) do
            if IsValid(Character) then
                local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
                local bIsAI = PlayerMapMarker.IsAI(Character)
                local KeyStr = tostring(PlayerKey)
                local Name = PlayerMapMarker.GetPlayerName(Character)

                local Loc = PlayerMapMarker.GetESPLocation(Character)

                local DistStr = ""
                if MyLoc and Loc then
                    DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc)
                end

                local bSkip = false
                if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
                if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end
                
                local TeamID = PlayerMapMarker.GetTeamID(Character)
                if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then
                    bSkip = true
                end

                local bIsAlive = PlayerMapMarker.IsAlive(Character)

                if not bSkip and Loc then
                    SeenKeys[KeyStr] = true
                    local ESPData = PlayerMapMarker.ESPWidgets[KeyStr]

                    local TeamID = PlayerMapMarker.GetTeamID(Character)

                    local Text = Name
                    if DistStr and DistStr ~= "" then
                        Text = string.format("%s [%s]", Name, DistStr)
                    end

                    local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)

                    if not ESPData then
                        if newMade >= newBudget then
                            goto nextPlayer
                        end
                        newMade = newMade + 1
                        local Widget = PlayerMapMarker.CreateESPWidget()
                        if Widget then
                            PlayerMapMarker.ESPWidgets[KeyStr] = {
                                Widget = Widget,
                                Character = Character,
                                Name = Name,
                                LastDistStr = DistStr,
                                TeamID = TeamID,
                            }
                            PlayerMapMarker.UpdateESPText(Widget, Text)
                            if bIsAlive then
                                PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
                                PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
                                local HP = Character.Health or 0
                                local MaxHP = Character.MaxHealth or 120
                                local pct = 0
                                if HP > 0 and MaxHP > 0 then
                                    pct = HP / MaxHP
                                    if pct > 1 then pct = 1 end
                                    if pct < 0 then pct = 0 end
                                end
                                PlayerMapMarker.UpdateESPHealth(Widget, pct)
                                PlayerMapMarker.AddWeaponIconToESP(Widget, Character)
                                
                                if PlayerMapMarker.bUseSnapLines then
                                    PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY,
                                            PlayerMapMarker.IsCharacterVisibleCached(KeyStr, Character), Character == _G._AIM_LOCKED_CHAR)
                                else
                                    PlayerMapMarker.RemoveSnapLine(KeyStr)
                                end
                            else
                                local Container = Widget.Container or Widget
                                pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                                PlayerMapMarker.UpdateESPHealth(Widget, 0)
                                PlayerMapMarker.RemoveSnapLine(KeyStr)
                            end
                        end
                    else
                        ESPData.Character = Character
                        ESPData.Name = Name
                        ESPData.LastDistStr = DistStr
                        if bIsAlive then
                            if TeamID ~= ESPData.TeamID then
                                ESPData.TeamID = TeamID
                                PlayerMapMarker.ApplyTeamColor(ESPData.Widget, TeamID)
                            end
                            PlayerMapMarker.UpdateESPText(ESPData.Widget, Text)
                            PlayerMapMarker.UpdateESPPositionWithPC(ESPData.Widget, Loc, PC, CanvasPos)
                            local HP = Character.Health or 0
                            local MaxHP = Character.MaxHealth or 120
                            local pct = 0
                            if HP > 0 and MaxHP > 0 then
                                pct = HP / MaxHP
                                if pct > 1 then pct = 1 end
                                if pct < 0 then pct = 0 end
                            end
                            PlayerMapMarker.UpdateESPHealth(ESPData.Widget, pct)
                            PlayerMapMarker.AddWeaponIconToESP(ESPData.Widget, Character)
                            
                            if PlayerMapMarker.bUseSnapLines then
                                PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY,
                                        PlayerMapMarker.IsCharacterVisibleCached(KeyStr, Character), Character == _G._AIM_LOCKED_CHAR)
                            else
                                PlayerMapMarker.RemoveSnapLine(KeyStr)
                            end
                        else
                            local Container = ESPData.Widget.Container or ESPData.Widget
                            pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                            PlayerMapMarker.UpdateESPHealth(ESPData.Widget, 0)
                            PlayerMapMarker.RemoveSnapLine(KeyStr)
                        end
                    end
                end
            end
            ::nextPlayer::
        end

        for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
            if not SeenKeys[KeyStr] then
                PlayerMapMarker.RemoveESPWidget(Data.Widget)
                PlayerMapMarker.RemoveSnapLine(KeyStr)
                PlayerMapMarker.ESPWidgets[KeyStr] = nil
            end
        end
    end

    function PlayerMapMarker.UpdateESPLight()
        pcall(ProcessAimbotFrame)

        -- ØªØ­Ø¯ÙŠØ« Ù…ÙˆÙ‚Ø¹ Ø§Ù„Ù…Ø³ØªØ·ÙŠÙ„ ÙÙŠ ÙƒÙ„ ÙØ±ÙŠÙ… Ù„ÙŠØ¨Ù‚Ù‰ Ù…Ø·Ø¨Ù‚Ø§Ù‹ ÙÙˆÙ‚ SnapLine ØªÙ…Ø§Ù…Ø§Ù‹ Ø¨Ø¯ÙˆÙ† lag
        if RedBoxOverlay.bActive then
            RedBoxOverlay.UpdatePosition()
        end

        if not PlayerMapMarker.bUseScreenESP then return end
        if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

        local PC = PlayerMapMarker.GetMyPlayerController()
        if not IsValid(PC) then return end

        PlayerMapMarker.UpdateCanvasTransform(PC)

        local fromX, fromY = 0, 0
        if PlayerMapMarker.bUseSnapLines then
            fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
        end

        for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
            local Widget = ESPData.Widget
            local Character = ESPData.Character
            local Container = Widget and (Widget.Container or Widget)
            local bWidgetValid = false
            pcall(function() bWidgetValid = Container and slua.isValid(Container) end)

            if Widget and bWidgetValid and Character and IsValid(Character) then
                local bIsAlive = PlayerMapMarker.IsAlive(Character)

                if not bIsAlive then
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                    PlayerMapMarker.RemoveSnapLine(KeyStr)
                else
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                    pcall(function() Container:SetRenderOpacity(1.0) end)

                    local Loc = PlayerMapMarker.GetESPLocation(Character)
                    if Loc then
                        local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
                        PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
                        if PlayerMapMarker.bUseSnapLines then
                            PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY,
                                    PlayerMapMarker.IsCharacterVisibleCached(KeyStr, Character), Character == _G._AIM_LOCKED_CHAR)
                        else
                            PlayerMapMarker.RemoveSnapLine(KeyStr)
                        end
                    else
                        PlayerMapMarker.RemoveSnapLine(KeyStr)
                    end
                end
            end
        end
    end

    function PlayerMapMarker.UpdateESPDistances()
        if not PlayerMapMarker.bUseScreenESP then return end

        local MyLoc = PlayerMapMarker.GetMyLocation()
        if not MyLoc then return end

        local PC = PlayerMapMarker.GetMyPlayerController()
        if not IsValid(PC) then return end

        PlayerMapMarker.UpdateCanvasTransform(PC)

        for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
            local Character = ESPData.Character
            local Widget = ESPData.Widget
            local Container = Widget and (Widget.Container or Widget)
            local bWidgetValid = false
            pcall(function() bWidgetValid = Container and slua.isValid(Container) end)
            if Character and IsValid(Character) and Widget and bWidgetValid then
                local Loc = PlayerMapMarker.GetESPLocation(Character)
                if Loc then
                    local Dist = PlayerMapMarker.CalcDistance(MyLoc, Loc)
                    ESPData.LastDistance = Dist

                    if PlayerMapMarker.bShowDistance then
                        local DistStr = ""
                        local Meters = 0
                        if Dist then
                            Meters = Dist / 100
                            if Meters < 1000 then
                                DistStr = string.format("%dm", math.floor(Meters))
                            else
                                DistStr = string.format("%.1fkm", Meters / 1000)
                            end
                        end

                        local Name = ESPData.Name or "Unknown"
                        local Text = Name
                        if DistStr and DistStr ~= "" then
                            Text = string.format("%s [%s]", Name, DistStr)
                        end
                        ESPData.LastDistStr = DistStr
                        PlayerMapMarker.UpdateESPText(Widget, Text)
                    end
                end
            end
        end
    end

    function PlayerMapMarker.OnTick(deltaTime)
        if not PlayerMapMarker.bActive then return end

        pcall(function()
            PlayerMapMarker._FrameCount = PlayerMapMarker._FrameCount + 1
            local frame = PlayerMapMarker._FrameCount

            if frame % PlayerMapMarker.nHeavyScanFrameInterval == 0 then
                local AllChars = PlayerMapMarker.GetAllCharacters()
                if AllChars then
                    local MyLoc = PlayerMapMarker.GetMyLocation()
                    PlayerMapMarker._CachedAllChars = AllChars
                    PlayerMapMarker._CachedMyLoc = MyLoc
                    PlayerMapMarker.UpdateESP(AllChars, MyLoc)
                end
            end

            if frame % PlayerMapMarker.nDistanceUpdateFrameInterval == 0 then
                PlayerMapMarker.UpdateESPDistances()
            end

            PlayerMapMarker.UpdateESPLight()
        end)
    end

    PlayerMapMarker._WorkingWidgetPath = nil
    PlayerMapMarker._FailedWidgetPaths = {}

    PlayerMapMarker.WidgetCompUIPaths = {
        "/Game/BluePrints/ControlInput/NewbieItem/NewbieTips_ConsumeTips.NewbieTips_ConsumeTips_C",
        "/Game/BluePrints/ControlInput/IngameUI/TipsItem/ChangeSight_Item01_UIBP.ChangeSight_Item01_UIBP_C",
        "/Game/Mod/PlanBT/BluePrints/UI/Fusion/FusionTitle_UIBP.FusionTitle_UIBP_C",
        "/Game/BluePrints/ControlInput/NewbieItem/NewbieTips_ConsumeTips.NewbieTips_ConsumeTips",
    }

    function PlayerMapMarker.CreateWidgetCompForPlayer(Character, Text)
        if not IsValid(Character) then return nil end
        local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
        if not Mesh or not Game:IsValid(Mesh) then return nil end

        if PlayerMapMarker._bAllPathsFailed then return nil end

        local PathsToTry = {}
        if PlayerMapMarker._WorkingWidgetPath then
            table.insert(PathsToTry, PlayerMapMarker._WorkingWidgetPath)
        else
            for _, path in ipairs(PlayerMapMarker.WidgetCompUIPaths) do
                if not PlayerMapMarker._FailedWidgetPaths[path] then
                    table.insert(PathsToTry, path)
                end
            end
        end

        if #PathsToTry == 0 then
            PlayerMapMarker._bAllPathsFailed = true
            return nil
        end

        local STExtraBlueprintFunctionLibrary = nil
        pcall(function() STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary") end)
        if not STExtraBlueprintFunctionLibrary then return nil end

        local Widget = nil
        local UsedPath = nil
        for _, path in ipairs(PathsToTry) do
            local ok = false
            pcall(function()
                Widget = STExtraBlueprintFunctionLibrary.CreateWidgetByPathName(path, Character)
                if Widget and slua.isValid(Widget) then ok = true end
            end)
            if ok and Widget then
                UsedPath = path
                PlayerMapMarker._WorkingWidgetPath = path
                break
            else
                Widget = nil
                PlayerMapMarker._FailedWidgetPaths[path] = true
            end
        end

        if not Widget then
            if not PlayerMapMarker._WorkingWidgetPath then
                PlayerMapMarker._bAllPathsFailed = true
            end
            return nil
        end

        local WidgetComp = nil
        pcall(function()
            local UWidgetComponent = import("WidgetComponent")
            WidgetComp = Game:AddComponent(UWidgetComponent, Character, "PlayerMapMarkerWidget")

            if WidgetComp and Game:IsValid(WidgetComp) then
                WidgetComp.AlwaysLoadOnClient = true
                WidgetComp.AlwaysLoadOnServer = false
                WidgetComp:SetOwnerNoSee(false)
                WidgetComp.bGenerateOverlapEvents = false
                WidgetComp.bCanEverAffectNavigation = false
                WidgetComp.bUseAttachParentBound = true
                WidgetComp.Space = 1

                pcall(function() WidgetComp:SetHiddenInGame(false) end)
                pcall(function() WidgetComp:SetVisibility(true) end)
                pcall(function() WidgetComp:SetComponentTickEnabled(true) end)

                pcall(function() WidgetComp:SetDrawSize(PlayerMapMarker.WidgetCompDrawSize) end)
                WidgetComp:SetWidget(Widget)
                WidgetComp:RequestRedraw()

                WidgetComp:K2_AttachToComponent(
                    Mesh,
                    PlayerMapMarker.WidgetCompBoneName,
                    UEnums.EAttachmentRule.SnapToTarget,
                    UEnums.EAttachmentRule.SnapToTarget,
                    UEnums.EAttachmentRule.KeepWorld,
                    false
                )

                local KismetMathLibrary = import("KismetMathLibrary")
                local Transform = KismetMathLibrary.MakeTransform(
                    PlayerMapMarker.WidgetCompOffset,
                    FRotator(0, 180, 0),
                    FVector(1, 1, 1)
                )
                WidgetComp:K2_SetRelativeTransform(Transform, false, nil, false)

                local UserWidget = WidgetComp:GetUserWidgetObject()
                if UserWidget and Game:IsValid(UserWidget) then
                    pcall(function()
                        if UserWidget.PlayerName then
                            UserWidget.PlayerName:SetText(Text or "")
                        elseif UserWidget.TextTitle then
                            UserWidget.TextTitle:SetText(Text or "")
                        elseif UserWidget.UTRichTextBlock_Tips22_Text1 then
                            UserWidget.UTRichTextBlock_Tips22_Text1:SetText(Text or "")
                        end
                    end)
                end

                CGame:RegisterComponent(WidgetComp)
                pcall(function() WidgetComp:RequestRedraw() end)
            end
        end)

        if not WidgetComp or not Game:IsValid(WidgetComp) then
            if WidgetComp and Game:IsValid(WidgetComp) then
                pcall(function() WidgetComp:DestroyComponent() end)
            end
            return nil
        end

        return WidgetComp
    end

    function PlayerMapMarker.UpdateWidgetCompText(WidgetComp, Text)
        if not WidgetComp or not Game:IsValid(WidgetComp) then return end
        pcall(function()
            local UserWidget = WidgetComp:GetUserWidgetObject()
            if UserWidget and Game:IsValid(UserWidget) then
                if UserWidget.PlayerName then
                    UserWidget.PlayerName:SetText(Text or "")
                elseif UserWidget.TextTitle then
                    UserWidget.TextTitle:SetText(Text or "")
                elseif UserWidget.UTRichTextBlock_Tips22_Text1 then
                    UserWidget.UTRichTextBlock_Tips22_Text1:SetText(Text or "")
                end
            end
        end)
    end

    function PlayerMapMarker.RemoveWidgetComp(WidgetComp)
        if not WidgetComp then return end
        pcall(function()
            if Game:IsValid(WidgetComp) then
                WidgetComp:K2_DetachFromComponent(2, false)
                local UserWidget = WidgetComp:GetUserWidgetObject()
                if UserWidget and Game:IsValid(UserWidget) then
                    UserWidget:RemoveFromViewport()
                    UserWidget:ConditionalBeginDestroy()
                end
                WidgetComp:DestroyComponent()
            end
        end)
    end

    function PlayerMapMarker.ClearAllWidgetComps()
        for KeyStr, WidgetComp in pairs(PlayerMapMarker.WidgetComps) do
            PlayerMapMarker.RemoveWidgetComp(WidgetComp)
        end
        PlayerMapMarker.WidgetComps = {}
    end

    function PlayerMapMarker.UpdateWidgetComps(AllPlayers, MyLoc)
        if not PlayerMapMarker.bUseWidgetComponent then return end
        if PlayerMapMarker._bAllPathsFailed then return end

        local MyKey = PlayerMapMarker.GetMyPlayerKey()
        local SeenKeys = {}

        for PlayerKey, Character in pairs(AllPlayers) do
            if IsValid(Character) then
                local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
                local bIsAI = PlayerMapMarker.IsAI(Character)
                local KeyStr = tostring(PlayerKey)
                local Name = PlayerMapMarker.GetPlayerName(Character)
                local Loc = PlayerMapMarker.GetCharacterLocation(Character)

                local DistStr = ""
                if MyLoc and Loc then
                    DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc)
                end

                local bSkip = false
                if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
                if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end

                if not bSkip then
                    SeenKeys[KeyStr] = true
                    local Text = Name
                    if DistStr and DistStr ~= "" then
                        Text = string.format("%s [%s]", Name, DistStr)
                    end

                    local ExistingComp = PlayerMapMarker.WidgetComps[KeyStr]
                    if not ExistingComp or not Game:IsValid(ExistingComp) then
                        local WidgetComp = PlayerMapMarker.CreateWidgetCompForPlayer(Character, Text)
                        if WidgetComp then
                            PlayerMapMarker.WidgetComps[KeyStr] = WidgetComp
                        end
                    else
                        PlayerMapMarker.UpdateWidgetCompText(ExistingComp, Text)
                    end
                end
            end
        end

        for KeyStr, WidgetComp in pairs(PlayerMapMarker.WidgetComps) do
            if not SeenKeys[KeyStr] then
                PlayerMapMarker.RemoveWidgetComp(WidgetComp)
                PlayerMapMarker.WidgetComps[KeyStr] = nil
            end
        end
    end

    function PlayerMapMarker.CreateMark(Location, CustomString, Actor)
        if not PlayerMapMarker.bUseScreenMark and not Location then return nil end

        local InstID = nil
        local Flag = GetMapAddedFlag()

        local MarkPos = Location
        if PlayerMapMarker.bUseScreenMark then
            MarkPos = nil
        end

        if PlayerMapMarker.bUseServerMarks then
            pcall(function()
                InstID = InGameMarkTools.ServerAddMapMark(
                    PlayerMapMarker.MarkTypeID,
                    MarkPos,
                    nil,
                    nil,
                    nil,
                    UEnums.EMarkDispatchRange.EMAMDT_ALL,
                    nil,
                    Actor
                )
            end)
        else
            pcall(function()
                local actorObj = Actor and (Actor.Object or Actor) or nil
                InstID = InGameMarkTools.ClientAddMapMark(
                    PlayerMapMarker.MarkTypeID,
                    MarkPos,
                    0,
                    CustomString or "",
                    Flag,
                    actorObj,
                    0,
                    nil
                )
            end)
        end

        return InstID
    end

    function PlayerMapMarker.UpdateMarkLocation(InstID, Location)
        if not InstID or not Location then return end
        pcall(function()
            InGameMarkTools.UpdateMapMarkLocation(InstID, Location)
        end)
    end

    function PlayerMapMarker.HideMark(InstID)
        if not InstID then return end
        pcall(function()
            InGameMarkTools.HideMapMark(InstID)
        end)
    end

    function PlayerMapMarker.ShowMark(InstID)
        if not InstID then return end
        pcall(function()
            InGameMarkTools.ShowMapMark(InstID)
        end)
    end

    function PlayerMapMarker.UpdateMarkString(InstID, sName)
        if not InstID or not sName then return end
        pcall(function()
            InGameMarkTools.UpdateMapMarkCustomString(InstID, sName)
        end)
    end

    function PlayerMapMarker.ClearAllMarks()
        for KeyStr, MarkID in pairs(PlayerMapMarker.MarkMap) do
            if PlayerMapMarker.bUseQuickSign then
                PlayerMapMarker.RemoveQuickSignMark(MarkID)
            elseif PlayerMapMarker.bUseNavigator then
                PlayerMapMarker.RemoveNavigatorMark(MarkID)
            else
                PlayerMapMarker.HideMark(MarkID)
            end
        end
        PlayerMapMarker.MarkMap = {}
        PlayerMapMarker.PlayerInfo = {}
        PlayerMapMarker.ClearAllWidgetComps()
        PlayerMapMarker.ClearAllESP()
    end

    function PlayerMapMarker.ScanAndUpdate()
        local AllChars = PlayerMapMarker.GetAllCharacters()
        if not AllChars then
            RedBoxOverlay.SetCounts(0, 0)
            return 0
        end

        local MyKey = PlayerMapMarker.GetMyPlayerKey()
        local MyLoc = PlayerMapMarker.GetMyLocation()

        local MyChar = nil
        pcall(function()
            local GDP = PlayerMapMarker.GetGameplayData()
            if GDP and GDP.GetLocalCharacter then
                MyChar = GDP.GetLocalCharacter()
            else
                local PC = PlayerMapMarker.GetMyPlayerController()
                if PC and PC.GetPawn then MyChar = PC:GetPawn() end
            end
        end)
        local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)

        -- 1. Ø­Ø³Ø§Ø¨ Ø£Ø¹Ø¯Ø§Ø¯ Ø§Ù„Ù„Ø§Ø¹Ø¨ÙŠÙ† ÙˆØ§Ù„Ø¨ÙˆØªØ§Øª Ø§Ù„Ø£Ø­ÙŠØ§Ø¡ (Ø¨Ø¯ÙˆÙ† Ø§Ù„Ù„Ø§Ø¹Ø¨ Ù†ÙØ³Ù‡ ÙˆØ§Ù„ØªÙŠÙ…)
        local realPlayers = 0
        local botPlayers = 0

        for PlayerKey, Character in pairs(AllChars) do
            if IsValid(Character) then
                local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
                local bIsAI = PlayerMapMarker.IsAI(Character)
                local bIsAlive = PlayerMapMarker.IsAlive(Character)

                if bIsAlive and not bIsMe then
                    local bIsMyTeam = false
                    if MyTeamID ~= nil then
                        local targetTeamID = PlayerMapMarker.GetTeamID(Character)
                        if targetTeamID == MyTeamID then
                            bIsMyTeam = true
                        end
                    end
                    
                    if not bIsMyTeam then
                        if bIsAI then
                            botPlayers = botPlayers + 1
                        else
                            realPlayers = realPlayers + 1
                        end
                    end
                end
            end
        end

        -- 2. Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø£Ø¹Ø¯Ø§Ø¯ Ù„Ù„Ù…Ø³ØªØ·ÙŠÙ„ ÙˆØ¶Ù…Ø§Ù† ØªØ´ØºÙŠÙ„Ù‡
        if RedBoxOverlay.bActive then
            RedBoxOverlay.SetCounts(realPlayers, botPlayers)
        elseif PlayerMapMarker.bUseRedBox ~= false then
            RedBoxOverlay.Start()
        end

        -- 3. Ø§Ø³ØªÙƒÙ…Ø§Ù„ Ø¨Ø§Ù‚ÙŠ Ø¹Ù…Ù„ÙŠØ© Ø§Ù„Ù…Ø³Ø­ ÙˆØ§Ù„Ù€ ESP
        if PlayerMapMarker.bUseScreenMark then
            PlayerMapMarker.SetupScreenMarkConfig()
        end

        if PlayerMapMarker.bUseScreenESP then
            PlayerMapMarker.UpdateESP(AllChars, MyLoc)
            return 0
        end

        if PlayerMapMarker.bUseWidgetComponent then
            PlayerMapMarker.UpdateWidgetComps(AllChars, MyLoc)
            return 0
        end

        local nCount = 0
        local nMarked = 0
        local nNewMarks = 0
        local nUpdated = 0
        local SeenKeys = {}

        for PlayerKey, Character in pairs(AllChars) do
            if IsValid(Character) then
                local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
                local bIsAI = PlayerMapMarker.IsAI(Character)
                local bIsAlive = PlayerMapMarker.IsAlive(Character)
                local KeyStr = tostring(PlayerKey)
                local Name = PlayerMapMarker.GetPlayerName(Character)
                local Loc = PlayerMapMarker.GetCharacterLocation(Character)

                local DistStr = ""
                if PlayerMapMarker.bShowDistance and MyLoc and Loc then
                    DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc)
                end

                local MarkText = Name
                if DistStr and DistStr ~= "" then
                    MarkText = string.format("%s (%s)", Name, DistStr)
                end

                nCount = nCount + 1
                SeenKeys[KeyStr] = true

                local bSkip = false
                if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
                if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end

                if not bSkip and Loc then
                    local ExistingMark = PlayerMapMarker.MarkMap[KeyStr]

                    if PlayerMapMarker.bUseQuickSign then
                        if ExistingMark then
                            PlayerMapMarker.RemoveQuickSignMark(ExistingMark)
                        end
                        local MsgID = PlayerMapMarker.CreateQuickSignMark(Loc)
                        if MsgID then
                            PlayerMapMarker.MarkMap[KeyStr] = MsgID
                            PlayerMapMarker.PlayerInfo[KeyStr] = {
                                Name = Name, bIsAlive = bIsAlive, bIsAI = bIsAI, bIsMe = bIsMe, LastDistStr = DistStr,
                            }
                            nMarked = nMarked + 1
                            if not ExistingMark then nNewMarks = nNewMarks + 1 else nUpdated = nUpdated + 1 end
                        end
                    elseif PlayerMapMarker.bUseNavigator then
                        if not ExistingMark then
                            local NavInstID = PlayerMapMarker.CreateNavigatorMark(Loc)
                            if NavInstID then
                                PlayerMapMarker.MarkMap[KeyStr] = NavInstID
                                PlayerMapMarker.PlayerInfo[KeyStr] = {
                                    Name = Name, bIsAlive = bIsAlive, bIsAI = bIsAI, bIsMe = bIsMe, LastDistStr = DistStr,
                                }
                                nMarked = nMarked + 1
                                nNewMarks = nNewMarks + 1
                            end
                        else
                            PlayerMapMarker.UpdateNavigatorMark(ExistingMark, Loc)
                            nMarked = nMarked + 1
                            nUpdated = nUpdated + 1
                            local OldInfo = PlayerMapMarker.PlayerInfo[KeyStr]
                            if OldInfo then
                                OldInfo.Name = Name
                                OldInfo.bIsAlive = bIsAlive
                                OldInfo.LastDistStr = DistStr
                            end
                        end
                    else
                        if not ExistingMark then
                            local InstID = PlayerMapMarker.CreateMark(Loc, MarkText, Character)
                            if InstID then
                                PlayerMapMarker.MarkMap[KeyStr] = InstID
                                PlayerMapMarker.ShowMark(InstID)
                                PlayerMapMarker.PlayerInfo[KeyStr] = {
                                    Name = Name, bIsAlive = bIsAlive, bIsAI = bIsAI, bIsMe = bIsMe, LastDistStr = DistStr,
                                }
                                nMarked = nMarked + 1
                                nNewMarks = nNewMarks + 1
                            end
                        else
                            if not PlayerMapMarker.bUseScreenMark then
                                PlayerMapMarker.UpdateMarkLocation(ExistingMark, Loc)
                            end
                            PlayerMapMarker.UpdateMarkString(ExistingMark, MarkText)
                            nMarked = nMarked + 1
                            nUpdated = nUpdated + 1
                            local OldInfo = PlayerMapMarker.PlayerInfo[KeyStr]
                            if OldInfo then
                                OldInfo.Name = Name
                                OldInfo.bIsAlive = bIsAlive
                                OldInfo.LastDistStr = DistStr
                            end
                        end
                    end
                elseif bSkip and PlayerMapMarker.MarkMap[KeyStr] then
                    if PlayerMapMarker.bUseQuickSign then
                        PlayerMapMarker.RemoveQuickSignMark(PlayerMapMarker.MarkMap[KeyStr])
                    elseif PlayerMapMarker.bUseNavigator then
                        PlayerMapMarker.RemoveNavigatorMark(PlayerMapMarker.MarkMap[KeyStr])
                    else
                        PlayerMapMarker.HideMark(PlayerMapMarker.MarkMap[KeyStr])
                    end
                    PlayerMapMarker.MarkMap[KeyStr] = nil
                    PlayerMapMarker.PlayerInfo[KeyStr] = nil
                end
            end
        end

        for KeyStr, MarkID in pairs(PlayerMapMarker.MarkMap) do
            if not SeenKeys[KeyStr] then
                if PlayerMapMarker.bUseQuickSign then
                    PlayerMapMarker.RemoveQuickSignMark(MarkID)
                elseif PlayerMapMarker.bUseNavigator then
                    PlayerMapMarker.RemoveNavigatorMark(MarkID)
                else
                    PlayerMapMarker.HideMark(MarkID)
                end
                PlayerMapMarker.MarkMap[KeyStr] = nil
                PlayerMapMarker.PlayerInfo[KeyStr] = nil
            end
        end

        return nCount
    end

    function PlayerMapMarker.AttachTimers()
        pcall(function()
            local pc = PlayerMapMarker.GetMyPlayerController()
            if not slua.isValid(pc) or not pc.AddGameTimer then
                local now = os.time()
                if PlayerMapMarker._AttachPending then
                    if PlayerMapMarker._AttachPendingTime and (now - PlayerMapMarker._AttachPendingTime) < 2 then return end
                end
                PlayerMapMarker._AttachPending = true
                PlayerMapMarker._AttachPendingTime = now
                PlayerMapMarker._bTimersAttached = false
                pcall(function()
                    require("timer").SetGameTimer(1.0, false, function()
                        PlayerMapMarker._AttachPending = nil
                        PlayerMapMarker._AttachPendingTime = nil
                        PlayerMapMarker.AttachTimers()
                    end)
                end)
                return
            end

            PlayerMapMarker._AttachPending = nil
            PlayerMapMarker._AttachPendingTime = nil

            local now = os.time()
            local lastPC = PlayerMapMarker._ActiveTimerPC
            if lastPC and slua.isValid(lastPC) and lastPC == pc and PlayerMapMarker._bTimersAttached then
                return
            end

            PlayerMapMarker._ActiveTimerPC = pc
            PlayerMapMarker._bTimersAttached = true
            PlayerMapMarker._ActiveTimerTick = now

            pcall(function()
                pc:AddGameTimer(PlayerMapMarker.nUpdateInterval or 0.5, true, function()
                    PlayerMapMarker._ActiveTimerTick = os.time()
                    if PlayerMapMarker.bActive then
                        pcall(function() PlayerMapMarker.ScanAndUpdate() end)
                    end
                end)
            end)

            pcall(function()
                pc:AddGameTimer(PlayerMapMarker._LightUpdateInterval or 0.02, true, function()
                    PlayerMapMarker._ActiveTimerTick = os.time()
                    if PlayerMapMarker.bActive then
                        pcall(function() PlayerMapMarker.UpdateESPLight() end)
                    end
                end)
            end)

            pcall(function()
                pc:AddGameTimer(PlayerMapMarker._DistanceUpdateInterval or 0.1, true, function()
                    PlayerMapMarker._ActiveTimerTick = os.time()
                    if PlayerMapMarker.bActive and PlayerMapMarker.bUseScreenESP and PlayerMapMarker.bShowDistance then
                        pcall(function() PlayerMapMarker.UpdateESPDistances() end)
                    end
                end)
            end)

            pcall(function()
                require("timer").SetGameTimer(5.0, false, PlayerMapMarker.AttachTimers)
            end)
        end)
    end

    function PlayerMapMarker.Start()
        if PlayerMapMarker.bActive then
            return
        end

        PlayerMapMarker.bActive = true
        PlayerMapMarker._FrameCount = 0

        PlayerMapMarker.ScanAndUpdate()
        PlayerMapMarker.AttachTimers()
    end

    function PlayerMapMarker.Stop()
        PlayerMapMarker.bActive = false
        PlayerMapMarker._FrameCount = 0
        PlayerMapMarker._bTimersAttached = false

        PlayerMapMarker.ClearAllMarks()
    end

    function PlayerMapMarker.Reset()
        PlayerMapMarker.ClearAllMarks()
    end

    function PlayerMapMarker.ManualScan()
        return PlayerMapMarker.ScanAndUpdate()
    end

    if _G._PlayerMapMarker_Loaded then
        PlayerMapMarker.Stop()
        PlayerMapMarker.Start()
    else
        _G._PlayerMapMarker_Loaded = true
        PlayerMapMarker.Start()
    end

    _G.PlayerMapMarker = PlayerMapMarker

    -- ============================================================
    -- SRCHUB MENU MODULE - OPTIMIZED FOR NO LAG (ZERO REPETITION)
    -- ============================================================
    local MY_TAB_VER = 16

    if not _G.__MyTabInstalled then
    _G.__MyTabInstalled = true

    local LOC = {
        MY_TAB             = 9990001,
        TAB_AIMBOT         = 9990011,
        TAB_MEMORY         = 9990014,
        
        BTN_AIMBOT_ENABLE  = 9990030,
        BTN_AIMBOT_FOV     = 9990031,
        BTN_AIMBOT_DIST    = 9990032,
        BTN_AIMBOT_SPEED   = 9990033,
        BTN_AIMBOT_KNOCK   = 9990034,
        BTN_AIMBOT_BOT     = 9990035,
        BTN_AIMBOT_RECOIL  = 9990036,
        
        BTN_MEM_GRASS      = 9990080,
        BTN_MEM_TREES      = 9990081,
        BTN_MEM_FOG        = 9990082,
        BTN_MEM_BLACKSKY   = 9990083,
        BTN_MEM_FPS        = 9990084,
        BTN_MEM_IPAD       = 9990085,
        BTN_MEM_IPAD_FOV   = 9990086,
        
        BTN_MEM_CROSSHAIR  = 9990087,
        
        OPT_ON             = 9990060,
        OPT_OFF            = 9990061,
        
        TITLE_AIMING       = 9990062,
        TITLE_SETTINGS     = 9990063,
    }

    local LOC_STR = {
        [LOC.MY_TAB]            = "SRCHUB MENU",
        [LOC.TAB_AIMBOT]        = "AIMBOT",
        [LOC.TAB_MEMORY]        = "MEMORY",
        
        [LOC.BTN_AIMBOT_ENABLE] = "Aimbot Enable",
        [LOC.BTN_AIMBOT_FOV]    = "Aimbot FOV",
        [LOC.BTN_AIMBOT_DIST]   = "Aimbot Max Dist",
        [LOC.BTN_AIMBOT_SPEED]  = "Aimbot Smooth Speed",
        [LOC.BTN_AIMBOT_KNOCK]  = "Ignore Knocked",
        [LOC.BTN_AIMBOT_BOT]    = "Ignore Bots",
        [LOC.BTN_AIMBOT_RECOIL] = "Recoil Comp",
        
        [LOC.BTN_MEM_GRASS]     = "Remove Grass",
        [LOC.BTN_MEM_TREES]     = "Remove Trees",
        [LOC.BTN_MEM_FOG]       = "Remove Fog",
        [LOC.BTN_MEM_BLACKSKY]  = "Black Sky",
        [LOC.BTN_MEM_FPS]       = "Unlock 165 FPS",
        [LOC.BTN_MEM_IPAD]      = "iPad View",
        [LOC.BTN_MEM_IPAD_FOV]  = "iPad FOV",
        
        [LOC.BTN_MEM_CROSSHAIR]  = "Small Crosshair",
        
        [LOC.OPT_ON]            = "ON",
        [LOC.OPT_OFF]           = "OFF",
        
        [LOC.TITLE_AIMING]      = "Aimbot Configuration",
        [LOC.TITLE_SETTINGS]    = "Memory Hacks",
    }

    _G.MemoryConfig = _G.MemoryConfig or {
        RemoveGrass = false,
        RemoveTrees = false,
        RemoveFog   = false,
        BlackSky    = false,
        UnlockFPS   = false,
        IpadView    = false,
        IpadFOV     = 120,
        _IpadWasActive = false,
        SmallCrosshair = false,
        _CrosshairWasActive = false,
    }

    local function ResolveLoc(id)
        return LOC_STR[id]
    end

    local function LOG(msg)
        pcall(print, "[SrcHubMenu] " .. tostring(msg))
    end

    LOG("SrcHubMenu v" .. MY_TAB_VER .. " loading...")

    local function ApplyMemoryFeature(feature, state)
        pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if not gi then
            gi = slua_GameFrontendHUD and slua_GameFrontendHUD:GetWorld()
        end
        if not gi then return end

        if feature == "Grass" then
            if state then
            gi:ExecuteCMD("grass.DensityScale", "0")
            gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
            else
            gi:ExecuteCMD("grass.DensityScale", "1")
            gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
            end
        elseif feature == "Trees" then
            if state then
            gi:ExecuteCMD("foliage.DensityScale", "0")
            gi:ExecuteCMD("r.Foliage.DensityScale", "0")
            gi:ExecuteCMD("foliage.MinimumScreenSize", "10000")
            gi:ExecuteCMD("r.DisableTreeRender", "1")
            else
            gi:ExecuteCMD("foliage.DensityScale", "1")
            gi:ExecuteCMD("r.Foliage.DensityScale", "1")
            gi:ExecuteCMD("foliage.MinimumScreenSize", "0")
            gi:ExecuteCMD("r.DisableTreeRender", "0")
            end
        elseif feature == "Fog" then
            if state then
            gi:ExecuteCMD("r.SkyAtmosphere", "1")
            gi:ExecuteCMD("r.Fog", "0")
            gi:ExecuteCMD("r.VolumetricFog", "0")
            else
            gi:ExecuteCMD("r.SkyAtmosphere", "1")
            gi:ExecuteCMD("r.Fog", "1")
            gi:ExecuteCMD("r.VolumetricFog", "1")
            end
        elseif feature == "BlackSky" then
            if state then
            gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
            else
            gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0")
            end
        elseif feature == "FPS" then
            local SettingCfg = require("client.logic.setting.setting_config")
            local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
            
            if state then
            if SettingCfg then
                if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
                if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
            end
            if GraphicSettingDB then
                if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
            end
            gi:ExecuteCMD("t.MaxFPS", "165")
            gi:ExecuteCMD("r.FrameRateLimit", "165")
            else
            if SettingCfg then
                if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 90 end
                if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 90 end
            end
            if GraphicSettingDB then
                if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 90 end
            end
            gi:ExecuteCMD("t.MaxFPS", "90")
            gi:ExecuteCMD("r.FrameRateLimit", "90")
            end
        end
        end)
    end

    local function RefreshAllMemoryFeatures()
        if not _G.MemoryConfig then return end
        ApplyMemoryFeature("Grass", _G.MemoryConfig.RemoveGrass)
        ApplyMemoryFeature("Trees", _G.MemoryConfig.RemoveTrees)
        ApplyMemoryFeature("Fog", _G.MemoryConfig.RemoveFog)
        ApplyMemoryFeature("BlackSky", _G.MemoryConfig.BlackSky)
        ApplyMemoryFeature("FPS", _G.MemoryConfig.UnlockFPS)
    end

RefreshAllMemoryFeatures()
    _G.ApplyMemoryFeatures = RefreshAllMemoryFeatures

    local function HookLoc(tbl, fname)
        if type(tbl) ~= "table" then return end
        if tbl["__mytab_hooked_" .. fname] then return end
        
        local orig = tbl[fname]
        if type(orig) ~= "function" then return end
        
        tbl["__mytab_hooked_" .. fname] = true
        tbl["__mytab_" .. fname] = orig
        
        tbl[fname] = function(...)
        local arg1 = select(1, ...)
        local id = arg1
        if type(arg1) == "table" and arg1 == tbl then
            id = select(2, ...)
        end
        
        local s = ResolveLoc(id)
        if s then return s end
        return orig(...)
        end
    end

    local function InstallLocHooks()
        local LocUtil = _G.LocUtil
        if not LocUtil then
        local ok, lu = pcall(require, "common.loc_util")
        if ok and lu then LocUtil = lu end
        end
        if type(LocUtil) == "table" then
        HookLoc(LocUtil, "GetLocalizeResStr")
        HookLoc(LocUtil, "GetLocalizeResStrV2")
        HookLoc(LocUtil, "TryGetLocalizeResStr")
        HookLoc(LocUtil, "ResolveText")
        end
        local DataMgr = _G.DataMgr
        if not DataMgr then
        local ok2, dm = pcall(require, "client.logic.data.data_mgr")
        if ok2 and dm then DataMgr = dm end
        end
        if type(DataMgr) == "table" then
        HookLoc(DataMgr, "GetMsgByID")
        HookLoc(DataMgr, "GetFormatMsgByID")
        end
    end

    InstallLocHooks()

    pcall(function()
        if type(slua) == "table" and type(slua.AddTickerDelegate) == "function" then
        local tries = 0
        slua.AddTickerDelegate(function()
            tries = tries + 1
            InstallLocHooks()
            return tries < 5
        end, 1.0)
        end
    end)

    local MY_TAB_DEFINE = {
        Key  = "MyTab",
        Text = LOC.MY_TAB,
    }

    local function GetMyTabDefine()
        if MY_TAB_DEFINE.Category then return MY_TAB_DEFINE end
        local cfg = UIManager and UIManager.UI_Config
        if not cfg then return MY_TAB_DEFINE end

        local SwitcherUI = cfg.Setting_Option_Switcher
        if not SwitcherUI then return MY_TAB_DEFINE end

        local TitleUI   = cfg.Setting_Title
        local SliderUI  = cfg.Setting_Option_Slider
        local SpacerUI  = cfg.Setting_Spacer

        local function MakeSwitcher(key, textId, getCb, setCb)
        return {
            Key          = "MyTab_" .. key,
            UI           = SwitcherUI,
            Text         = textId,
            SwitcherText = { LOC.OPT_ON, LOC.OPT_OFF },
            GetFunc = function(item)
            local index = getCb()
            if type(item) == "table" then item.CurrentIndex = index end
            return index
            end,
            SetFunc = function(item, index)
            setCb(index)
            if type(item) == "table" then
                item.CurrentIndex = index
                item.SelectedIndex = index
                item.Value = index
                pcall(function()
                if item.SetSelectedIndex then item:SetSelectedIndex(index) end
                if item.UpdateView then item:UpdateView() end
                if item.RefreshUI then item:RefreshUI() end
                end)
            end
            return true
            end,
        }
        end

        local function MakeSlider(key, textId, minVal, maxVal, getCb, setCb)
        return {
            Key      = "MyTab_" .. key,
            UI       = SliderUI,
            Text     = textId,
            Min      = minVal,
            Max      = maxVal,
            GetFunc  = function(item)
            local val = getCb()
            if type(item) == "table" then item.Value = val end
            return val
            end,
            SetFunc  = function(item, val)
            setCb(val)
            if type(item) == "table" then
                item.Value = val
                pcall(function()
                if item.UpdateView then item:UpdateView() end
                if item.RefreshUI then item:RefreshUI() end
                end)
            end
            end,
        }
        end

        local function MakeStack(sections)
        local stack = {}
        for secIdx, sec in ipairs(sections) do
            if secIdx > 1 and SpacerUI then
            stack[#stack + 1] = {
                Key  = "MyTab_spacer_" .. tostring(#stack),
                UI   = SpacerUI,
            }
            end
            if TitleUI and sec.title then
            stack[#stack + 1] = {
                Key  = "MyTab_title_" .. tostring(secIdx),
                UI   = TitleUI,
                Text = sec.title,
            }
            end
            for _, item in ipairs(sec.items or {}) do
            stack[#stack + 1] = item
            end
        end
        return stack
        end

        local tab1Section1 = {
        MakeSwitcher("aim_enable", LOC.BTN_AIMBOT_ENABLE, 
            function() return (_G.AimbotConfig and _G.AimbotConfig.Enable) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.Enable = (idx == 1) end end
        )
        }

        local tab1Section2 = {
        MakeSlider("aim_fov", LOC.BTN_AIMBOT_FOV, 1, 300,
            function() return _G.AimbotConfig and _G.AimbotConfig.FOV or 30 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.FOV = val end end
        ),
        MakeSlider("aim_dist", LOC.BTN_AIMBOT_DIST, 1, 500,
            function() return _G.AimbotConfig and _G.AimbotConfig.Distance or 250 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.Distance = val end end
        ),
        MakeSlider("aim_speed", LOC.BTN_AIMBOT_SPEED, 1, 100,
            function() return _G.AimbotConfig and _G.AimbotConfig.Speed or 50 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.Speed = val end end
        ),
        MakeSwitcher("aim_knock", LOC.BTN_AIMBOT_KNOCK,
            function() return (_G.AimbotConfig and _G.AimbotConfig.IgnoreKnock) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.IgnoreKnock = (idx == 1) end end
        ),
        MakeSwitcher("aim_bot", LOC.BTN_AIMBOT_BOT,
            function() return (_G.AimbotConfig and _G.AimbotConfig.IgnoreBot) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.IgnoreBot = (idx == 1) end end
        ),
        MakeSlider("aim_recoil", LOC.BTN_AIMBOT_RECOIL, 0, 100,
            function() return _G.AimbotConfig and _G.AimbotConfig.RecoilComp or 0 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.RecoilComp = val end end
        ),
        }

        local tab2Section1 = {
        MakeSwitcher("mem_grass", LOC.BTN_MEM_GRASS,
            function() return (_G.MemoryConfig.RemoveGrass and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.RemoveGrass = (idx == 1) 
                ApplyMemoryFeature("Grass", _G.MemoryConfig.RemoveGrass)
            end
        ),
        MakeSwitcher("mem_trees", LOC.BTN_MEM_TREES,
            function() return (_G.MemoryConfig.RemoveTrees and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.RemoveTrees = (idx == 1) 
                ApplyMemoryFeature("Trees", _G.MemoryConfig.RemoveTrees)
            end
        ),
        MakeSwitcher("mem_fog", LOC.BTN_MEM_FOG,
            function() return (_G.MemoryConfig.RemoveFog and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.RemoveFog = (idx == 1) 
                ApplyMemoryFeature("Fog", _G.MemoryConfig.RemoveFog)
            end
        ),
        MakeSwitcher("mem_blacksky", LOC.BTN_MEM_BLACKSKY,
            function() return (_G.MemoryConfig.BlackSky and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.BlackSky = (idx == 1) 
                ApplyMemoryFeature("BlackSky", _G.MemoryConfig.BlackSky)
            end
        ),
        MakeSwitcher("mem_fps", LOC.BTN_MEM_FPS,
            function() return (_G.MemoryConfig.UnlockFPS and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.UnlockFPS = (idx == 1) 
                ApplyMemoryFeature("FPS", _G.MemoryConfig.UnlockFPS)
            end
        ),
        MakeSwitcher("mem_crosshair", LOC.BTN_MEM_CROSSHAIR,
            function() return (_G.MemoryConfig.SmallCrosshair and 1 or 2) end,
            function(idx) _G.MemoryConfig.SmallCrosshair = (idx == 1) end
        ),
        MakeSwitcher("mem_ipad", LOC.BTN_MEM_IPAD,
            function() return (_G.MemoryConfig.IpadView and 1 or 2) end,
            function(idx) _G.MemoryConfig.IpadView = (idx == 1) end
        ),
        MakeSlider("mem_ipad_fov", LOC.BTN_MEM_IPAD_FOV, 60, 160,
            function() return _G.MemoryConfig.IpadFOV or 120 end,
            function(val) _G.MemoryConfig.IpadFOV = val end
        ),
        }

        MY_TAB_DEFINE.Category = {
        {
            Key   = "MyTab_TAB1",
            Text  = LOC.TAB_AIMBOT,
            UIKey = "Setting_Page_Game",
            Stack = MakeStack({
            { title = LOC.TITLE_AIMING,   items = tab1Section1 },
            { title = LOC.TITLE_SETTINGS, items = tab1Section2 },
            }),
        },
        {
            Key   = "MyTab_TAB2",
            Text  = LOC.TAB_MEMORY,
            UIKey = "Setting_Page_Game",
            Stack = MakeStack({
            { title = LOC.TITLE_SETTINGS, items = tab2Section1 },
            }),
        },
        }

        LOG("GetMyTabDefine: built successfully.")
        return MY_TAB_DEFINE
    end

    local function HasMyTab(catalog)
        if type(catalog) ~= "table" then return false end
        for _, item in ipairs(catalog) do
        if type(item) == "table" and item.Key == "MyTab" then return true end
        end
        return false
    end

    local function InjectMyTab(catalog)
        if type(catalog) ~= "table" then return end
        if HasMyTab(catalog) then return end
        GetMyTabDefine()
        table.insert(catalog, 1, MY_TAB_DEFINE)
        LOG("InjectMyTab: inserted at position 1")
    end

    if type(UIManager) == "table" and type(UIManager.ShowUI) == "function" then
        if UIManager.__mytab_ShowUI then
        UIManager.ShowUI = UIManager.__mytab_ShowUI
        UIManager.__mytab_ShowUI = nil
        end
        UIManager.__mytab_ShowUI = UIManager.ShowUI
        
        UIManager.ShowUI = function(...)
        local uiKey = select(1, ...)
        local arg1 = uiKey
        local args_start = 1
        if type(arg1) == "table" and arg1 == UIManager then
            uiKey = select(2, ...)
            args_start = 2
        end
        
        local cfg = UIManager.UI_Config
        if cfg and uiKey == cfg.setting_main then
            local catArg = select(args_start + 1, ...)
            if type(catArg) == "table" then InjectMyTab(catArg) end
        end
        return UIManager.__mytab_ShowUI(...)
        end
        LOG("UIManager.ShowUI hooked")
    end

    local SettingMainPath = "client.slua.umg.NewSetting.Main.setting_main_base"
    local okSM, SettingMain = pcall(require, SettingMainPath)
    if okSM and SettingMain then
        local Impl = SettingMain.__inner_impl
        if Impl then
            local function RebuildMyTab(self)
                if not self or not self.UIRoot then return false end
                if self._PageUI then
                    pcall(function() self._PageUI:CloseSelf() end)
                end
                self._PageUI = nil
                if self._CategoryUI then
                    pcall(function() self._CategoryUI:CloseSelf() end)
                end
                self._CategoryUI = nil

                local def = GetMyTabDefine()
                if not def or not def.Category then return false end

                local pageData = self.AvailablePageList and self.AvailablePageList[1]
                self._CurrentPage = (pageData and pageData.Key == "MyTab") and pageData or def
                self._AvailableCategoryList = def.Category

                pcall(function()
                    self.UIRoot.HorizontalSelector_Category:SetNum(#def.Category)
                    for i, catData in ipairs(def.Category) do
                        local Child = self.UIRoot.HorizontalSelector_Category:GetChildAt(i - 1)
                        if slua.isValid(Child) and Child.TextBlock_Name then
                            pcall(function() Child.TextBlock_Name:SetText(ResolveLoc(catData.Text) or tostring(catData.Text)) end)
                        end
                    end
                    self.UIRoot.HorizontalSelector_Category:SetSelectedIndex(-1)
                    self.UIRoot.HorizontalSelector_Category:SetSelectedIndex(0)
                end)

                pcall(function() self:SetWidgetVisible(self.UIRoot.Border_Header, true) end)
                pcall(function()
                    self:PlayUserWidgetAnimation(self.UIRoot.Fadein_Page, 0, 1, 0, 1)
                end)
                return true
            end

            if not Impl.__mytab_OnSelectTab_Page then
                Impl.__mytab_OnSelectTab_Page = Impl.OnSelectTab_Page
                Impl.OnSelectTab_Page = function(self, ItemIndex)
                    local pageData = self.AvailablePageList and self.AvailablePageList[ItemIndex + 1]
                    if pageData and pageData.Key == "MyTab" then
                        return RebuildMyTab(self)
                    end
                    return Impl.__mytab_OnSelectTab_Page(self, ItemIndex)
                end
                LOG("OnSelectTab_Page hooked")
            end

            if not Impl.__mytab_OnShowFadeIn then
                Impl.__mytab_OnShowFadeIn = Impl.OnShowFadeIn
                Impl.OnShowFadeIn = function(self)
                    local ok, ret = pcall(Impl.__mytab_OnShowFadeIn, self)
                    pcall(function()
                        if self._CurrentPage and self._CurrentPage.Key == "MyTab" then
                            if not self._CategoryUI then
                                RebuildMyTab(self)
                            end
                        end
                    end)
                    return ret
                end
                LOG("OnShowFadeIn hooked")
            end

            if not Impl.__mytab_OnClose then
                Impl.__mytab_OnClose = Impl.OnClose
                Impl.OnClose = function(self)
                    self._PageUI = nil
                    self._CategoryUI = nil
                    self._CurrentPage = nil
                    self._AvailableCategoryList = {}
                    return Impl.__mytab_OnClose(self)
                end
                LOG("OnClose hooked")
            end
        end
    end

    if type(UIManager) == "table" and type(UIManager.HideUI) == "function" then
        if UIManager.__mytab_HideUI then
        UIManager.HideUI = UIManager.__mytab_HideUI
        UIManager.__mytab_HideUI = nil
        end
        UIManager.__mytab_HideUI = UIManager.HideUI
        UIManager.HideUI = function(...)
        local uiKey = select(1, ...)
        local arg1 = uiKey
        local args_start = 1
        if type(arg1) == "table" and arg1 == UIManager then
            uiKey = select(2, ...)
            args_start = 2
        end
        
        local cfg = UIManager.UI_Config
        if cfg and uiKey == cfg.setting_main then
            local ui = UIManager.GetUI and UIManager.GetUI(cfg.setting_main)
            if ui then ui.__mytabInstalled = nil end
        end
        return UIManager.__mytab_HideUI(...)
        end
    end

    LOG("SrcHubMenu v" .. MY_TAB_VER .. " globally installed.")
    end

    -- ============================================
    -- BRPLAYERCHARACTERBASE CLASS & GAME INTEGRATION
    -- ============================================
    local class = require("class")
    local CharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
    local combine_class = require("combine_class")

    local BRPlayerCharacterBase = {}

    function BRPlayerCharacterBase:ctor() end

    function BRPlayerCharacterBase:postConstruct()
        CharacterBase._PostConstruct(self)
    end

    function BRPlayerCharacterBase:receiveBeginPlay()
        CharacterBase.ReceiveBeginPlay(self)
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if self and self.Controller and pc and self.Controller == pc then
                if PlayerMapMarker then
                    PlayerMapMarker.Stop()
                    PlayerMapMarker.Start()
                end
            end
        end)
    end

    function BRPlayerCharacterBase:receiveEndPlay(endPlayReason)
        CharacterBase.ReceiveEndPlay(self, endPlayReason)
    end

    local FinalCharacterClass = class(CharacterBase, nil, {
        ctor = BRPlayerCharacterBase.ctor,
        _PostConstruct = BRPlayerCharacterBase.postConstruct,
        ReceiveBeginPlay = BRPlayerCharacterBase.receiveBeginPlay,
        ReceiveEndPlay = BRPlayerCharacterBase.receiveEndPlay,
    })

    return combine_class.DeclareFeature(FinalCharacterClass, {
        SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature",
        CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature",
        SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature",
        TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature",
        LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature",
        FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature",
    }, "BRPlayerCharacterBase")