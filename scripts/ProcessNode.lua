---@class Info
---@field node number | nil
---@field width number
---@field length number
---@field zOffset number
---@field yOffset number
---@field limitToGround boolean
---@field useRaycastHitPosition boolean

---@class Raycast
---@field node number | nil
---@field useWorldNegYDirection boolean
---@field yOffset number

---@class NodeTrigger
---@field node number | nil
---@field objects table
---@field numObjects number

---@class ProcessNode
---@field index number
---@field processor Processor
---@field vehicle Distributor
---@field spec SPEC_distributor
---
---@field i3dNode number
---@field fillUnit FillUnitObject
---@field fillUnitIndex number
---@field effectTurnOffThreshold number
---@field lineOffset number
---@field litersToDrop number
---@field emptySpeed number
---@field toolType number
---@field maxDistance number
---@field info Info
---@field raycast Raycast
---@field trigger NodeTrigger
---@field activationTrigger NodeTrigger
---@field effects Effect[]
---@field playSound boolean
---@field soundNode number | nil
---@field dischargeSample table | nil
---@field dischargeStateSamples table
---@field animationNodes table
---
---@field distanceObjectChanges table
---@field distanceObjectChangeThreshold number
---@field stateObjectChanges table
---@field nodeActiveObjectChanges table
---@field currentDischargeState number
---@field canStartGroundDischargeAutomatically boolean
---@field sample table | nil
---
---@field dischargeObject table | nil
---@field dischargeHit boolean
---@field dischargeHitObject table | nil
---@field dischargeHitObjectUnitIndex number | nil
---@field dischargeHitTerrain boolean
---@field dischargeShape number | nil
---@field dischargeDistance number
---@field dischargeDistanceSent number
---@field sentHitDistance number
---@field dischargeFillUnitIndex number | nil
---@field isEffectActive boolean
---@field isEffectActiveSent boolean
---@field lastEffect Effect | nil
---@field currentDischargeObject table | nil
ProcessNode = {}
local ProcessNode_mt = Class(ProcessNode)

ProcessNode.NUM_BITS_INDEX = 4

---@param index number
---@param processor Processor
---@param mt any
---@return ProcessNode
function ProcessNode.new(index, processor, mt)
    ---@type ProcessNode
    local self = setmetatable({}, mt or ProcessNode_mt)

    self.index = index
    self.processor = processor
    self.vehicle = processor.vehicle
    self.spec = self.vehicle.spec_distributor
    self.emptySpeed = 250

    return self
end

---@param xmlFile XMLFile
---@param path string
function ProcessNode:load(xmlFile, path)
    self.fillUnitIndex = xmlFile:getValue(path .. '#fillUnitIndex')
    ---@diagnostic disable-next-line: assign-type-mismatch
    self.fillUnit = self.vehicle:getFillUnitByIndex(self.fillUnitIndex)
    self.emptySpeed = xmlFile:getValue(path .. '#emptySpeed', self.emptySpeed)

    if self.fillUnit == nil then
        g_debugger:error('ProcessNode:load() Failed to find vehicle fillUnit: %i', self.fillUnitIndex)
        return false
    end

    self.i3dNode = xmlFile:getValue(path .. '#i3d', nil, self.vehicle.components, self.vehicle.i3dMappings)
    self.effectTurnOffThreshold = xmlFile:getValue(path .. '#effectTurnOffThreshold', 0.25)
    self.stopDischargeOnEmpty = xmlFile:getValue(path .. '#stopDischargeOnEmpty', true)
    self.stopDischargeIfNotPossible = xmlFile:getValue(path .. '#stopDischargeIfNotPossible', xmlFile:hasProperty(path .. '.trigger#node'))
    self.canStartDischargeAutomatically = xmlFile:getValue(path .. '#canStartDischargeAutomatically', true)
    self.canStartGroundDischargeAutomatically = xmlFile:getValue(path .. '#canStartGroundDischargeAutomatically', true)

    self.lineOffset = 0
    self.litersToDrop = 0
    self.toolType = g_toolTypeManager:getToolTypeIndexByName('dischargable')

    self:loadInfo(xmlFile, path)
    self:loadRaycast(xmlFile, path)
    self:loadTriggers(xmlFile, path)
    self:loadObjectChanges(xmlFile, path)
    self:loadEffects(xmlFile, path)

    self.dischargeObject = nil
    self.dischargeHitObject = nil
    self.dischargeHitObjectUnitIndex = nil
    self.dischargeHitTerrain = false
    self.dischargeShape = nil
    self.dischargeDistance = 0
    self.dischargeDistanceSent = 0
    self.dischargeFillUnitIndex = nil
    self.dischargeHit = false
    self.sentHitDistance = 0
    self.isEffectActive = false
    self.isEffectActiveSent = false
    self.lastEffect = self.effects[#self.effects]
    self.currentDischargeState = Dischargeable.DISCHARGE_STATE_OFF

    return true
end

function ProcessNode:onDelete()
    g_effectManager:deleteEffects(self.effects)
    g_soundManager:deleteSample(self.sample)
    g_soundManager:deleteSample(self.dischargeSample)
    g_soundManager:deleteSamples(self.dischargeStateSamples)
    g_animationManager:deleteAnimations(self.animationNodes)

    if self.trigger.node ~= nil then
        removeTrigger(self.trigger.node)
    end

    if self.activationTrigger.node ~= nil then
        removeTrigger(self.activationTrigger.node)
    end
end

---@private
---@param xmlFile XMLFile
---@param path string
function ProcessNode:loadInfo(xmlFile, path)
    self.unloadInfoIndex = xmlFile:getValue(path .. '#unloadInfoIndex', 1)

    self.info = {}

    self.info.width = xmlFile:getValue(path .. '.info#width', 1) / 2
    self.info.length = xmlFile:getValue(path .. '.info#length', 1) / 2
    self.info.zOffset = xmlFile:getValue(path .. '.info#zOffset', 0)
    self.info.yOffset = xmlFile:getValue(path .. '.info#yOffset', 2)
    self.info.limitToGround = xmlFile:getValue(path .. '.info#limitToGround', true)
    self.info.useRaycastHitPosition = xmlFile:getValue(path .. '.info#useRaycastHitPosition', false)

    self.info.node = xmlFile:getValue(path .. '.info#node', self.i3dNode, self.vehicle.components, self.vehicle.i3dMappings)

    if self.info.node == self.i3dNode then
        self.info.node = createTransformGroup('dischargeInfoNode')
        link(self.i3dNode, self.info.node)
    end
end

---@private
---@param xmlFile XMLFile
---@param path string
function ProcessNode:loadRaycast(xmlFile, path)
    self.raycast = {}

    self.raycast.useWorldNegYDirection = xmlFile:getValue(path .. '.raycast#useWorldNegYDirection', false)
    self.raycast.yOffset = xmlFile:getValue(path .. '.raycast#yOffset', 0)

    self.raycast.node = xmlFile:getValue(path .. '.raycast#node', self.i3dNode, self.vehicle.components, self.vehicle.i3dMappings)

    local maxDistance = xmlFile:getValue(path .. '.raycast#maxDistance', 10)
    self.maxDistance = xmlFile:getValue(path .. '#maxDistance', maxDistance)
end

---@private
---@param xmlFile XMLFile
---@param path string
function ProcessNode:loadTriggers(xmlFile, path)
    self.trigger = {}
    self.trigger.node = xmlFile:getValue(path .. '.trigger#node', nil, self.vehicle.components, self.vehicle.i3dMappings)
    self.trigger.objects = {}
    self.trigger.numObjects = 0

    if self.trigger.node ~= nil then
        addTrigger(self.trigger.node, 'dischargeTriggerCallback', self)
    end


    self.activationTrigger = {}
    self.activationTrigger.node = xmlFile:getValue(path .. '.activationTrigger#node', nil, self.vehicle.components, self.vehicle.i3dMappings)
    self.activationTrigger.objects = {}
    self.activationTrigger.numObjects = 0

    if self.activationTrigger.node ~= nil then
        addTrigger(self.activationTrigger.node, 'dischargeActivationTriggerCallback', self)
    end
end

---@private
---@param xmlFile XMLFile
---@param path string
function ProcessNode:loadObjectChanges(xmlFile, path)
    self.distanceObjectChanges = {}
    ObjectChangeUtil.loadObjectChangeFromXML(xmlFile, path .. '.distanceObjectChanges', self.distanceObjectChanges, self.vehicle.components, self.vehicle)

    if #self.distanceObjectChanges == 0 then
        self.distanceObjectChanges = nil
    else
        self.distanceObjectChangeThreshold = xmlFile:getValue(path .. '.distanceObjectChanges#threshold', 0.5)
        ObjectChangeUtil.setObjectChanges(self.distanceObjectChanges, false, self.vehicle, self.vehicle.setMovingToolDirty)
    end


    self.stateObjectChanges = {}
    ObjectChangeUtil.loadObjectChangeFromXML(xmlFile, path .. '.stateObjectChanges', self.stateObjectChanges, self.vehicle.components, self.vehicle)

    if #self.stateObjectChanges == 0 then
        self.stateObjectChanges = nil
    else
        ObjectChangeUtil.setObjectChanges(self.stateObjectChanges, false, self.vehicle, self.vehicle.setMovingToolDirty)
    end


    self.nodeActiveObjectChanges = {}
    ObjectChangeUtil.loadObjectChangeFromXML(xmlFile, path .. '.nodeActiveObjectChanges', self.nodeActiveObjectChanges, self.vehicle.components, self.vehicle)

    if #self.nodeActiveObjectChanges == 0 then
        self.nodeActiveObjectChanges = nil
    else
        ObjectChangeUtil.setObjectChanges(self.nodeActiveObjectChanges, false, self.vehicle, self.vehicle.setMovingToolDirty)
    end
end

---@private
---@param xmlFile XMLFile
---@param path string
function ProcessNode:loadEffects(xmlFile, path)
    self.effects = g_effectManager:loadEffect(xmlFile, path .. '.effects', self.vehicle.components, self.vehicle, self.vehicle.i3dMappings)

    if self.vehicle.isClient then
        self.playSound = xmlFile:getValue(path .. '#playSound')
        self.soundNode = xmlFile:getValue(path .. '#soundNode', nil, self.vehicle.components, self.vehicle.i3dMappings)

        if self.playSound then
            self.dischargeSample = g_soundManager:loadSampleFromXML(xmlFile, path, 'dischargeSound', self.vehicle.baseDirectory, self.vehicle.components, 0, AudioGroup.VEHICLE, self.vehicle.i3dMappings, self.vehicle)
        end

        if xmlFile:getValue(path .. '.dischargeSound#overwriteSharedSound', false) then
            self.playSound = false
        end

        self.dischargeStateSamples = g_soundManager:loadSamplesFromXML(xmlFile, path, "dischargeStateSound", self.vehicle.baseDirectory, self.vehicle.components, 0, AudioGroup.VEHICLE, self.vehicle.i3dMappings, self.vehicle)
        self.animationNodes = g_animationManager:loadAnimations(xmlFile, path .. ".animationNodes", self.vehicle.components, self.vehicle, self.vehicle.i3dMappings)
    end
end

function ProcessNode:onUpdate(dt)
    if self.activationTrigger.numObjects > 0 or self.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF then
        self.vehicle:raiseActive()
    end
end

function ProcessNode:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.vehicle:getIsTurnedOn() then
        local trigger = self.trigger

        if trigger.numObjects > 0 then
            local lastDischargeObject = self.dischargeObject
            self.dischargeObject = nil
            self.dischargeHitObject = nil
            self.dischargeHitObjectUnitIndex = nil
            self.dischargeHitTerrain = false
            self.dischargeShape = nil
            self.dischargeDistance = 0
            self.dischargeFillUnitIndex = nil
            self.dischargeHit = false

            local nearestDistance = math.huge

            for object, data in pairs(trigger.objects) do
                local fillTypeIndex = self:getCurrentFillTypeIndex()

                self.dischargeFailedReason = nil
                self.dischargeFailedReasonShowAuto = false
                self.customNotAllowedWarning = nil

                if object:getFillUnitSupportsFillType(data.fillUnitIndex, fillTypeIndex) then
                    local allowFillType = object:getFillUnitAllowsFillType(data.fillUnitIndex, fillTypeIndex)
                    local allowToolType = object:getFillUnitSupportsToolType(data.fillUnitIndex, ToolType.TRIGGER)
                    local freeSpace = object:getFillUnitFreeCapacity(data.fillUnitIndex, fillTypeIndex, self.vehicle:getActiveFarm()) > 0
                    local accessible = object:getIsFillAllowedFromFarm(self.vehicle:getActiveFarm())


                    if allowFillType and allowToolType and freeSpace then
                        local exactFillRootNode = object:getFillUnitExactFillRootNode(data.fillUnitIndex)

                        if exactFillRootNode ~= nil and entityExists(exactFillRootNode) then
                            local distance = calcDistanceFrom(self.i3dNode, exactFillRootNode)

                            if distance < nearestDistance then
                                self.dischargeObject = object
                                self.dischargeHitTerrain = false
                                self.dischargeShape = data.shape
                                self.dischargeDistance = distance
                                self.dischargeFillUnitIndex = data.fillUnitIndex
                                nearestDistance = distance

                                if object ~= lastDischargeObject then
                                    SpecializationUtil.raiseEvent(self.vehicle, "onDischargeTargetObjectChanged", object)
                                end
                            end
                        end
                    end

                    self.dischargeHitObject = object
                    self.dischargeHitObjectUnitIndex = data.fillUnitIndex
                end

                self.dischargeHit = true
            end

            if lastDischargeObject ~= nil and self.dischargeObject == nil then
                SpecializationUtil.raiseEvent(self.vehicle, "onDischargeTargetObjectChanged", nil)
            end
        elseif not self.isAsyncRaycastActive then
            self:updateRaycast()
        end
    end

    self:updateDischargeSound(dt)

    if self.vehicle.isServer then
        local currentDischargeState = self:getCurrentDischargeState()

        if currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF then
            if self.dischargeObject ~= nil then
                self:handleFoundDischargeObject()
            end
        elseif currentDischargeState == Dischargeable.DISCHARGE_STATE_GROUND and self.dischargeObject ~= nil and self:getCanDischargeToObject() then
            self:handleFoundDischargeObject()
        elseif self.vehicle:getIsTurnedOn() then
            local fillLevel = self.vehicle:getFillUnitFillLevel(self.fillUnitIndex) or 0
            local canDischargeToObject = self:getCanDischargeToObject() and currentDischargeState == Dischargeable.DISCHARGE_STATE_OBJECT
            local canDischargeToGround = self:getCanDischargeToGround() and currentDischargeState == Dischargeable.DISCHARGE_STATE_GROUND
            local canDischarge = canDischargeToObject or canDischargeToGround
            local allowedToDischarge = self.dischargeObject ~= nil or self:getCanDischargeToLand() and self:getCanDischargeAtPosition()
            local isReadyToStartDischarge = fillLevel > 0 and self.emptySpeed > 0 and allowedToDischarge and canDischarge

            self:setDischargeEffectActive(isReadyToStartDischarge)
            self:setDischargeEffectDistance(self.dischargeDistance)

            if allowedToDischarge then
                local emptyLiters = math.min(fillLevel, self.emptySpeed * dt)

                local dischargedLiters, minDropReached, hasMinDropFillLevel = self:discharge(emptyLiters)
                self.dischargedLiters = dischargedLiters
                self:handleDischarge(dischargedLiters, minDropReached, hasMinDropFillLevel)
            end
        end

        if self.isEffectActive ~= self.isEffectActiveSent or math.abs(self.dischargeDistanceSent - self.dischargeDistance) > 0.05 then
            self.vehicle:raiseDirtyFlags(self.vehicle.spec_distributor.dirtyFlag)

            self.dischargeDistanceSent = self.dischargeDistance
            self.isEffectActiveSent = self.isEffectActive
        end
    end

    if self:getCurrentDischargeState() == Dischargeable.DISCHARGE_STATE_OFF then
        if self.vehicle:getIsActiveForInput() and self:getCanDischargeToObject() and self:getCanDischargeToObject() then
            g_currentMission:showTipContext(self.vehicle:getFillUnitFillType(self.fillUnitIndex))
        end
    end

    if self.stopEffectTime ~= nil then
        if self.stopEffectTime < g_time then
            self:setDischargeEffectActive(false, true)
            self.stopEffectTime = nil
        else
            self.vehicle:raiseActive()
        end
    end
end

function ProcessNode:getCurrentDischargeState()
    return self.currentDischargeState
end

---@return FillUnit | nil
---@return number | nil
function ProcessNode:getDischargeTargetObject()
    return self.dischargeObject, self.dischargeFillUnitIndex
end

---@return number dischargedLiters
---@return boolean minDropReached
---@return boolean hasMinDropFillLevel
function ProcessNode:discharge(emptyLiters)
    local dischargedLiters = 0
    local minDropReached = true
    local hasMinDropFillLevel = true

    local object, fillUnitIndex = self:getDischargeTargetObject()
    local currentDischargeState = self:getCurrentDischargeState()

    self.currentDischargeObject = nil

    if object ~= nil then
        if currentDischargeState == Dischargeable.DISCHARGE_STATE_OBJECT then
            dischargedLiters = self:dischargeToObject(emptyLiters, object, fillUnitIndex)
        end
    elseif self.dischargeHitTerrain and currentDischargeState == Dischargeable.DISCHARGE_STATE_GROUND then
        dischargedLiters, minDropReached, hasMinDropFillLevel = self:dischargeToGround(emptyLiters)
    end

    return dischargedLiters, minDropReached, hasMinDropFillLevel
end

---@return number dischargedLiters
---@return boolean minDropReached
---@return boolean hasMinDropFillLevel
function ProcessNode:dischargeToGround(emptyLiters)
    -- DEBUG
    if self.totalDropped == nil then
        self.totalDropped = 0
        self.totalDischarged = 0
    end



    if emptyLiters == 0 then
        return 0, false, false
    end

    local input = self.processor:getCurrentInput()

    if input == nil then
        return 0, false, false
    end

    local output = input.outputsByFillUnitIndex[self.fillUnitIndex]

    if output == nil then
        return 0, false, false
    end

    local fillTypeIndex = output.fillTypeIndex
    local fillLevel = output:getFillLevel()
    local minValidLiter = g_densityMapHeightManager:getMinValidLiterValue(fillTypeIndex)

    self.litersToDrop = math.min(self.litersToDrop + emptyLiters, fillLevel)

    if self.litersToDrop < minValidLiter then
        if input:getFillLevel() < 0.001 then
            self:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
            self.fillUnit.fillLevel = 0
            self.litersToDrop = 0
        end

        return 0, false, false
    end



    local dischargedLiters = 0
    local minDropReached = minValidLiter < self.litersToDrop


    if minDropReached then
        local info = self.info
        local sx, sy, sz = localToWorld(info.node, -info.width, 0, info.zOffset)
        local ex, ey, ez = localToWorld(info.node, info.width, 0, info.zOffset)
        sy = sy + info.yOffset
        ey = ey + info.yOffset

        if info.limitToGround then
            sy = math.max(getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 0, sz) + 0.1, sy)
            ey = math.max(getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, ex, 0, ez) + 0.1, ey)
        end

        local dropped, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(self.vehicle, self.litersToDrop, fillTypeIndex, sx, sy, sz, ex, ey, ez, info.length, nil, self.lineOffset, true, nil, true)
        self.lineOffset = lineOffset
        self.litersToDrop = self.litersToDrop - dropped


        self.debugDropped = dropped
        self.totalDropped = self.totalDropped + dropped

        if dropped > 0 then
            local unloadInfo = self.vehicle:getFillVolumeUnloadInfo(self.unloadInfoIndex)
            dischargedLiters = self.vehicle:addFillUnitFillLevel(self.vehicle:getOwnerFarmId(), self.fillUnitIndex, -dropped, fillTypeIndex, ToolType.UNDEFINED, unloadInfo)

            self.totalDischarged = self.totalDischarged + dischargedLiters
        end
    end

    return dischargedLiters, minDropReached, false
end

---@return number dischargedLiters
function ProcessNode:dischargeToObject(emptyLiters, object, targetFillUnitIndex)
    local factor = 1
    local fillTypeIndex = self:getCurrentFillTypeIndex()
    local supportsFillType = object:getFillUnitSupportsFillType(targetFillUnitIndex, fillTypeIndex)
    local dischargedLiters = 0

    if supportsFillType then
        local allowFillType = object:getFillUnitAllowsFillType(targetFillUnitIndex, fillTypeIndex)

        if allowFillType then
            self.currentDischargeObject = object
            local delta = object:addFillUnitFillLevel(self.vehicle:getActiveFarm(), targetFillUnitIndex, emptyLiters * factor, fillTypeIndex, self.toolType, self.info)
            delta = delta / factor
            local unloadInfo = self.vehicle:getFillVolumeUnloadInfo(self.unloadInfoIndex)
            dischargedLiters = self.vehicle:addFillUnitFillLevel(self.vehicle:getOwnerFarmId(), self.fillUnitIndex, -delta, fillTypeIndex, ToolType.UNDEFINED, unloadInfo)
        end
    end

    return dischargedLiters
end

---@param state number
---@param noEventSend boolean | nil
function ProcessNode:setDischargeState(state, noEventSend)
    if state ~= self.currentDischargeState then
        SetDischargeNodeState.sendEvent(self.vehicle, self.index, state, noEventSend)

        self.currentDischargeState = state

        if state == Dischargeable.DISCHARGE_STATE_OFF then
            self:setDischargeEffectActive(false)
            self.isEffectActiveSent = false
            g_animationManager:stopAnimations(self.animationNodes)
        else
            g_animationManager:startAnimations(self.animationNodes)
        end

        if self.stateObjectChanges ~= nil then
            ObjectChangeUtil.setObjectChanges(self.stateObjectChanges, state ~= Dischargeable.DISCHARGE_STATE_OFF, self.vehicle, self.vehicle.setMovingToolDirty)
        end

        ---@diagnostic disable-next-line: undefined-field
        if self.vehicle.setDashboardsDirty ~= nil then
            ---@diagnostic disable-next-line: undefined-field
            self.vehicle:setDashboardsDirty()
        end

        SpecializationUtil.raiseEvent(self.vehicle, "onDischargeStateChanged", state)
    end
end

---@return boolean
function ProcessNode:getCanDischargeToGround()
    local spec = self.vehicle.spec_distributor

    if not spec.canDischargeToGround then
        return false
    end

    if not self.dischargeHitTerrain then
        return false
    end


    if self.vehicle:getFillUnitFillLevel(self.fillUnitIndex) > 0 then
        local fillTypeIndex = self:getCurrentFillTypeIndex()

        if fillTypeIndex == nil or not DensityMapHeightUtil.getCanTipToGround(fillTypeIndex) then
            return false
        end
    end

    if not self:getCanDischargeToLand() then
        return false
    end

    if not self:getCanDischargeAtPosition() then
        return false
    end

    return true
end

---@return ProcessOutput | nil
function ProcessNode:getOutput()
    local input = self.processor:getCurrentInput()

    if input ~= nil then
        return input.outputsByFillUnitIndex[self.fillUnitIndex]
    end
end

---@return number
function ProcessNode:getCurrentFillTypeIndex()
    local output = self:getOutput()

    if output ~= nil then
        return output.fillTypeIndex
    end

    return FillType.UNKNOWN
end

---@return FillTypeObject | nil
function ProcessNode:getCurrentFillType()
    local output = self:getOutput()

    if output ~= nil then
        return output.fillType
    end
end

---@return boolean
function ProcessNode:getCanDischargeToLand()
    local spec = self.vehicle.spec_distributor

    if spec.canDischargeToGroundAnywhere then
        return true
    end

    local info = self.info
    local sx, _, sz = localToWorld(info.node, -info.width, 0, info.zOffset)
    local ex, _, ez = localToWorld(info.node, info.width, 0, info.zOffset)
    local activeFarm = self.vehicle:getActiveFarm()

    if not g_currentMission.accessHandler:canFarmAccessLand(activeFarm, sx, sz) then
        return false
    end

    if not g_currentMission.accessHandler:canFarmAccessLand(activeFarm, ex, ez) then
        return false
    end

    return true
end

---@return boolean
function ProcessNode:getCanDischargeAtPosition()
    if self.vehicle:getFillUnitFillLevel(self.fillUnitIndex) > 0 then
        local info = self.info
        local sx, sy, sz = localToWorld(info.node, -info.width, 0, info.zOffset)
        local ex, ey, ez = localToWorld(info.node, info.width, 0, info.zOffset)

        if self.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF or self.currentDischargeState == Dischargeable.DISCHARGE_STATE_GROUND then
            sy = sy + info.yOffset
            ey = ey + info.yOffset

            if info.limitToGround then
                sy = math.max(getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 0, sz) + 0.1, sy)
                ey = math.max(getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, ex, 0, ez) + 0.1, ey)
            end

            local fillType = self:getCurrentFillTypeIndex()

            if fillType == nil then
                return false
            end

            local testDrop = g_densityMapHeightManager:getMinValidLiterValue(fillType)

            if not DensityMapHeightUtil.getCanTipToGroundAroundLine(self, testDrop, fillType, sx, sy, sz, ex, ey, ez, info.length, nil, self.lineOffset, true, nil, true) then
                return false
            end
        end
    end

    return true
end

---@return boolean
function ProcessNode:getCanDischargeToObject()
    ---@type FillUnit
    local object = self.dischargeObject

    if object == nil then
        self.debugText = 'dischargeObject is nil'
        return false
    end

    local fillTypeIndex = self:getCurrentFillTypeIndex()

    if fillTypeIndex == nil then
        self.debugText = 'fillTypeIndex is nil'
        return false
    end

    if not object:getFillUnitSupportsFillType(self.dischargeFillUnitIndex, fillTypeIndex) then
        self.debugText = 'getFillUnitSupportsFillType is not supported'
        return false
    end

    local allowFillType = object:getFillUnitAllowsFillType(self.dischargeFillUnitIndex, fillTypeIndex)

    if not allowFillType then
        self.debugText = 'allowFillType: false'
        return false
    end

    local activeFarmId = self.vehicle:getActiveFarm()

    if object.getFillUnitFreeCapacity ~= nil and object:getFillUnitFreeCapacity(self.dischargeFillUnitIndex, nil, activeFarmId) <= 0 then
        self.debugText = 'getFillUnitFreeCapacity: no capacity'
        return false
    end

    if object.getIsFillAllowedFromFarm ~= nil and not object:getIsFillAllowedFromFarm(activeFarmId) then
        self.debugText = 'getIsFillAllowedFromFarm: false'
    end

    ---@diagnostic disable-next-line: undefined-field
    if self.vehicle.getMountObject ~= nil then
        ---@diagnostic disable-next-line: undefined-field
        local mounter = self.vehicle:getDynamicMountObject() or self.vehicle:getMountObject()

        if mounter ~= nil and not g_currentMission.accessHandler:canFarmAccess(mounter:getActiveFarm(), self.vehicle, true) then
            self.debugText = 'no from mounter -> accessHandler'
            return false
        end
    end

    return true
end

local RAYCAST_COLLISION_MASK = CollisionFlag.FILLABLE + CollisionFlag.VEHICLE + CollisionFlag.TERRAIN

---@private
function ProcessNode:updateRaycast()
    local raycast = self.raycast

    if raycast.node == nil then
        return
    end

    self.lastDischargeObject = self.dischargeObject
    self.dischargeObject = nil
    self.dischargeHitObject = nil
    self.dischargeHitObjectUnitIndex = nil
    self.dischargeHitTerrain = false
    self.dischargeShape = nil
    self.dischargeDistance = math.huge
    self.dischargeFillUnitIndex = nil
    self.dischargeHit = false

    local x, y, z = getWorldTranslation(raycast.node)
    local dx = 0
    local dy = -1
    local dz = 0
    y = y + raycast.yOffset

    if not raycast.useWorldNegYDirection then
        dx, dy, dz = localDirectionToWorld(raycast.node, 0, -1, 0)
    end

    self.isAsyncRaycastActive = true

    raycastAll(x, y, z, dx, dy, dz, "raycastCallbackDischargeNode", self.maxDistance, self, RAYCAST_COLLISION_MASK, false, false)

    ---@diagnostic disable-next-line: missing-parameter
    self:raycastCallbackDischargeNode(nil)
end

---@param x number
---@param y number
---@param z number
function ProcessNode:updateDischargeInfo(x, y, z)
    if self.info.useRaycastHitPosition then
        setWorldTranslation(self.info.node, x, y, z)
    end
end

---@private
---@param hitActorId number | nil
---@param x number
---@param y number
---@param z number
---@param distance number
---@param nx number
---@param ny number
---@param nz number
---@param subShapeIndex number | nil
---@param hitShapeId number | nil
function ProcessNode:raycastCallbackDischargeNode(hitActorId, x, y, z, distance, nx, ny, nz, subShapeIndex, hitShapeId)
    if hitActorId == nil then
        self:finishDischargeRaycast()
        return
    end

    local object = g_currentMission:getNodeObject(hitActorId)
    distance = distance - self.raycast.yOffset

    local validObject = object ~= nil and object ~= self.vehicle

    if validObject and distance < 0 and object.getFillUnitIndexFromNode ~= nil then
        validObject = validObject and object:getFillUnitIndexFromNode(hitShapeId) ~= nil
    end

    if validObject then
        if object.getFillUnitIndexFromNode ~= nil then
            local fillUnitIndex = object:getFillUnitIndexFromNode(hitShapeId)

            if fillUnitIndex ~= nil then
                local fillTypeIndex = self:getCurrentFillTypeIndex()

                if object:getFillUnitSupportsFillType(fillUnitIndex, fillTypeIndex) then
                    local allowFillType = object:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex)
                    local allowToolType = object:getFillUnitSupportsToolType(fillUnitIndex, self.toolType)
                    local freeSpace = object:getFillUnitFreeCapacity(fillUnitIndex, fillTypeIndex, self.vehicle:getActiveFarm()) > 0
                    local accessible = object:getIsFillAllowedFromFarm(self.vehicle:getActiveFarm())

                    if allowFillType and allowToolType and freeSpace then
                        self.dischargeObject = object
                        self.dischargeShape = hitShapeId
                        self.dischargeDistance = distance
                        self.dischargeFillUnitIndex = fillUnitIndex

                        if object.getFillUnitExtraDistanceFromNode ~= nil then
                            self.dischargeExtraDistance = object:getFillUnitExtraDistanceFromNode(hitShapeId)
                        end
                    end
                end

                self.dischargeHit = true
                self.dischargeHitObject = object
                self.dischargeHitObjectUnitIndex = fillUnitIndex
            elseif self.dischargeHit then
                self.dischargeDistance = distance + (self.dischargeExtraDistance or 0)
                self.dischargeExtraDistance = nil

                self:updateDischargeInfo(x, y, z)

                return false
            end
        end
    elseif hitActorId == g_currentMission.terrainRootNode then
        self.dischargeDistance = math.min(self.dischargeDistance, distance)
        self.dischargeHitTerrain = true

        self:updateDischargeInfo(x, y, z)

        return false
    end

    return true
end

---@private
function ProcessNode:finishDischargeRaycast()
    self:handleDischargeRaycast(self.lastDischargeObject)
    self.isAsyncRaycastActive = false

    if self.lastDischargeObject ~= self.dischargeObject then
        SpecializationUtil.raiseEvent(self.vehicle, 'onDischargeTargetObjectChanged', self.dischargeObject)
    end
end

function ProcessNode:handleDischargeOnEmpty()
    self:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, true)
end

---@private
---@param dischargedLiters number
---@param minDropReached boolean
---@param hasMinDropFillLevel boolean
function ProcessNode:handleDischarge(dischargedLiters, minDropReached, hasMinDropFillLevel)
    if self.currentDischargeState == Dischargeable.DISCHARGE_STATE_GROUND then
    elseif self.stopDischargeIfNotPossible and dischargedLiters == 0 then
        self:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
    end
end

---@private
---@param object table | nil
---@param shape any | nil
---@param distance number | nil
---@param fillUnitIndex number | nil
---@param hitTerrain boolean | nil
function ProcessNode:handleDischargeRaycast(object, shape, distance, fillUnitIndex, hitTerrain)
    if object == nil and self.currentDischargeState == Dischargeable.DISCHARGE_STATE_OBJECT then
        self:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
    elseif object == nil and self.canStartGroundDischargeAutomatically and self:getCanDischargeToGround() then
        self:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
    end

    if self.distanceObjectChanges ~= nil then
        ObjectChangeUtil.setObjectChanges(self.distanceObjectChanges, self.distanceObjectChangeThreshold < distance or self.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF, self.vehicle, self.vehicle.setMovingToolDirty)
    end
end

---@private
function ProcessNode:handleFoundDischargeObject()
    self:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
end

---@param distance number
function ProcessNode:setDischargeEffectDistance(distance)
    if self.isEffectActive and self.effects ~= nil and distance ~= math.huge then
        for _, effect in pairs(self.effects) do
            ---@diagnostic disable-next-line: undefined-field
            if effect.setDistance ~= nil then
                ---@diagnostic disable-next-line: undefined-field
                effect:setDistance(distance, g_currentMission.terrainRootNode)
            end
        end
    end
end

---@param isActive boolean
---@param force boolean | nil
---@param fillTypeIndex number | nil
function ProcessNode:setDischargeEffectActive(isActive, force, fillTypeIndex)
    if isActive then
        if not self.isEffectActive then
            if fillTypeIndex == nil then
                fillTypeIndex = self:getCurrentFillTypeIndex()
            end

            g_effectManager:setFillType(self.effects, fillTypeIndex)
            g_effectManager:startEffects(self.effects)

            self.isEffectActive = true
        end

        self.stopEffectTime = nil
    elseif force == nil or not force then
        if self.stopEffectTime == nil then
            self.stopEffectTime = g_time + self.effectTurnOffThreshold

            self.vehicle:raiseActive()
        end
    elseif self.isEffectActive then
        g_effectManager:stopEffects(self.effects)

        self.isEffectActive = false
    end
end

---@private
---@param dt number
function ProcessNode:updateDischargeSound(dt)
    if not self.vehicle.isClient then
        return
    end

    local fillTypeIndex = self:getCurrentFillTypeIndex()
    local isInDischargeState = self.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF
    local isEffectActive = self.isEffectActive and fillTypeIndex ~= FillType.UNKNOWN
    local lastEffectVisible = self.lastEffect == nil or self.lastEffect:getIsVisible()
    local effectsStillActive = self.lastEffect ~= nil and self.lastEffect:getIsVisible()

    if (isInDischargeState and isEffectActive or effectsStillActive) and lastEffectVisible then
        if self.playSound and fillTypeIndex ~= FillType.UNKNOWN then
            local sharedSample = g_fillTypeManager:getSampleByFillType(fillTypeIndex)

            if sharedSample ~= nil then
                if sharedSample ~= self.sharedSample then
                    if self.sample ~= nil then
                        g_soundManager:deleteSample(self.sample)
                    end

                    self.sample = g_soundManager:cloneSample(sharedSample, self.i3dNode or self.soundNode, self)
                    self.sharedSample = sharedSample

                    g_soundManager:playSample(self.sample)
                elseif not g_soundManager:getIsSamplePlaying(self.sample) then
                    g_soundManager:playSample(self.sample)
                end
            end
        end

        if self.dischargeSample ~= nil and not g_soundManager:getIsSamplePlaying(self.dischargeSample) then
            g_soundManager:playSample(self.dischargeSample)
        end

        self.turnOffSoundTimer = 250
    elseif self.turnOffSoundTimer ~= nil and self.turnOffSoundTimer > 0 then
        self.turnOffSoundTimer = self.turnOffSoundTimer - dt

        if self.turnOffSoundTimer <= 0 then
            if self.playSound and g_soundManager:getIsSamplePlaying(self.sample) then
                g_soundManager:stopSample(self.sample)
            end

            if self.dischargeSample ~= nil and g_soundManager:getIsSamplePlaying(self.dischargeSample) then
                g_soundManager:stopSample(self.dischargeSample)
            end

            self.turnOffSoundTimer = 0
        end
    end

    if self.dischargeStateSamples ~= nil and #self.dischargeStateSamples > 0 then
        for i = 1, #self.dischargeStateSamples do
            local sample = self.dischargeStateSamples[i]

            if isInDischargeState then
                if not g_soundManager:getIsSamplePlaying(sample) then
                    g_soundManager:playSample(sample)
                end
            elseif g_soundManager:getIsSamplePlaying(sample) then
                g_soundManager:stopSample(sample)
            end
        end
    end
end

---@private
---@param triggerId number
---@param otherActorId number
---@param onEnter boolean
---@param onLeave boolean
---@param onStay boolean
---@param otherShapeId number | nil
function ProcessNode:dischargeTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        local object = g_currentMission:getNodeObject(otherActorId)

        if object ~= nil and object ~= self and object.getFillUnitIndexFromNode ~= nil then
            local fillUnitIndex = object:getFillUnitIndexFromNode(otherShapeId)

            if fillUnitIndex ~= nil then
                local trigger = self.trigger

                if onEnter then
                    if trigger.objects[object] == nil then
                        trigger.objects[object] = {
                            count = 0,
                            fillUnitIndex = fillUnitIndex,
                            shape = otherShapeId
                        }
                        trigger.numObjects = trigger.numObjects + 1

                        object:addDeleteListener(self, "onDeleteDischargeTriggerObject")
                    end

                    trigger.objects[object].count = trigger.objects[object].count + 1

                    self.vehicle:raiseActive()
                elseif onLeave then
                    trigger.objects[object].count = trigger.objects[object].count - 1

                    if trigger.objects[object].count == 0 then
                        trigger.objects[object] = nil
                        trigger.numObjects = trigger.numObjects - 1

                        object:removeDeleteListener(self, "onDeleteDischargeTriggerObject")
                    end
                end
            end
        end
    end
end

---@private
---@param triggerId number
---@param otherActorId number
---@param onEnter boolean
---@param onLeave boolean
---@param onStay boolean
---@param otherShapeId number | nil
function ProcessNode:dischargeActivationTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if onLeave then
        self.debugTrigger = nil
    end

    if onEnter or onLeave then
        local object = g_currentMission:getNodeObject(otherActorId)

        if object ~= nil and object ~= self and object.getFillUnitIndexFromNode ~= nil then
            local fillUnitIndex = object:getFillUnitIndexFromNode(otherShapeId)

            if fillUnitIndex ~= nil then
                local trigger = self.activationTrigger

                if onEnter then
                    self.debugTrigger = fillUnitIndex

                    if trigger.objects[object] == nil then
                        trigger.objects[object] = {
                            count = 0,
                            fillUnitIndex = fillUnitIndex,
                            shape = otherShapeId
                        }
                        trigger.numObjects = trigger.numObjects + 1

                        object:addDeleteListener(self, "onDeleteActivationTriggerObject")
                    end

                    trigger.objects[object].count = trigger.objects[object].count + 1

                    self.vehicle:raiseActive()
                elseif onLeave then
                    trigger.objects[object].count = trigger.objects[object].count - 1

                    if trigger.objects[object].count == 0 then
                        trigger.objects[object] = nil
                        trigger.numObjects = trigger.numObjects - 1

                        object:removeDeleteListener(self, "onDeleteActivationTriggerObject")
                    end
                end
            end
        end
    end
end

---@private
---@param object table
function ProcessNode:onDeleteDischargeTriggerObject(object)
    if self.trigger.objects[object] ~= nil then
        self.trigger.objects[object] = nil
        self.trigger.numObjects = self.trigger.numObjects - 1
    end
end

---@private
---@param object table
function ProcessNode:onDeleteActivationTriggerObject(object)
    if self.activationTrigger.objects[object] ~= nil then
        self.activationTrigger.objects[object] = nil
        self.activationTrigger.numObjects = self.activationTrigger.numObjects - 1
    end
end

--[[
    SCHEMA
]]
---@param schema XMLSchema
function ProcessNode.registerXMLSchema(schema)
    local path = 'vehicle.distributor.processor.nodes.node(?)'

    schema:register(XMLValueType.INT, path .. '#fillUnitIndex', 'Node fillUnit index', nil, true)
    schema:register(XMLValueType.INT, path .. '#unloadInfoIndex', 'Unload info index', 1)
    schema:register(XMLValueType.FLOAT, path .. '#effectTurnOffThreshold', 'After this time has passed and nothing has been harvested the effects are turned off', 0.25)
    schema:register(XMLValueType.FLOAT, path .. '#maxDistance', 'Max discharge distance', 10)

    schema:register(XMLValueType.NODE_INDEX, path .. '#i3d', '', nil, true)

    schema:register(XMLValueType.BOOL, path .. '#canStartDischargeAutomatically', '', true)
    schema:register(XMLValueType.BOOL, path .. '#canStartGroundDischargeAutomatically', '', true)
    schema:register(XMLValueType.BOOL, path .. '#stopDischargeOnEmpty', '', true)
    schema:register(XMLValueType.BOOL, path .. '#stopDischargeIfNotPossible', '', false)

    schema:register(XMLValueType.INT, path .. '#emptySpeed', 'Empty speed in liters/second', 250)

    --[[
        INFO
    ]]
    schema:register(XMLValueType.FLOAT, path .. '.info#width', '', 1)
    schema:register(XMLValueType.FLOAT, path .. '.info#length', '', 1)
    schema:register(XMLValueType.FLOAT, path .. '.info#zOffset', '', 1)
    schema:register(XMLValueType.FLOAT, path .. '.info#yOffset', '', 1)
    schema:register(XMLValueType.BOOL, path .. '.info#limitToGround', '', true)
    schema:register(XMLValueType.BOOL, path .. '.info#useRaycastHitPosition', '', false)

    --[[
        RAYCAST
    ]]
    schema:register(XMLValueType.NODE_INDEX, path .. ".raycast#node", "Raycast node", "Discharge node")
    schema:register(XMLValueType.FLOAT, path .. ".raycast#yOffset", "Y Offset", 0)
    schema:register(XMLValueType.FLOAT, path .. ".raycast#maxDistance", "Max. raycast distance", 10)
    schema:register(XMLValueType.BOOL, path .. ".raycast#useWorldNegYDirection", "Use world negative Y Direction", false)

    --[[
        TRIGGERS
    ]]
    schema:register(XMLValueType.NODE_INDEX, path .. ".info#node", "Discharge info node", "Discharge node")
    schema:register(XMLValueType.NODE_INDEX, path .. ".trigger#node", "Discharge trigger node")
    schema:register(XMLValueType.NODE_INDEX, path .. ".activationTrigger#node", "Discharge activation trigger node")

    --[[
        OBJECT CHANGES
    ]]
    schema:register(XMLValueType.FLOAT, path .. ".distanceObjectChanges#threshold", "Defines at which raycast distance the object changes", 0.5)
    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, path .. '.distanceObjectChanges')
    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, path .. ".stateObjectChanges")
    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, path .. ".nodeActiveObjectChanges")

    --[[
        EFFECTS
    ]]
    schema:register(XMLValueType.NODE_INDEX, path .. '#soundNode', 'Sound node index path')
    schema:register(XMLValueType.BOOL, path .. '#playSound', 'Whether to play sounds', true)
    EffectManager.registerEffectXMLPaths(schema, path .. ".effects")
    SoundManager.registerSampleXMLPaths(schema, path, "dischargeSound")
    SoundManager.registerSampleXMLPaths(schema, path, "dischargeStateSound(?)")
    schema:register(XMLValueType.BOOL, path .. ".dischargeSound#overwriteSharedSound", "Overwrite shared discharge sound with sound defined in discharge node", false)
    AnimationManager.registerAnimationNodesXMLPaths(schema, path .. ".animationNodes")
end

--[[
    DEBUG
]]
---@param x number
---@param y number
---@return number
function ProcessNode:onDebugDraw(x, y)
    local stateStr = 'unknown'

    local function text(str)
        renderText(x, y, 0.014, str)
        y = y - 0.014
    end

    if self.currentDischargeState == Dischargeable.DISCHARGE_STATE_GROUND then
        stateStr = 'STATE_GROUND'
    elseif self.currentDischargeState == Dischargeable.DISCHARGE_STATE_OBJECT then
        stateStr = 'STATE_OBJECT'
    elseif self.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF then
        stateStr = 'STATE_OFF'
    end

    local fillType = self:getCurrentFillType()

    local title = fillType and fillType.title or ''

    setTextBold(true)
    text('State: ' .. stateStr)
    setTextBold(false)
    text('fillType: ' .. title)
    text('getCanDischargeToGround: ' .. tostring(self:getCanDischargeToGround()))
    text('getCanDischargeToObject: ' .. tostring(self:getCanDischargeToObject()))
    text(' ')
    text('dischargeHit: ' .. tostring(self.dischargeHit))
    text('dischargeHitTerrain: ' .. tostring(self.dischargeHitTerrain))
    text('currentDischargeObject: ' .. tostring(self.currentDischargeObject))
    text('dischargeObject: ' .. tostring(self.dischargeObject))
    text('dischargeHitObject: ' .. tostring(self.dischargeHitObject))
    text('dischargeHitObjectUnitIndex: ' .. tostring(self.dischargeHitObjectUnitIndex))
    text('lastDischargeObject: ' .. tostring(self.lastDischargeObject))
    text(' ')
    text('debugText: ' .. tostring(self.debugText))

    return y
end
