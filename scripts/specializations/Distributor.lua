local modName = g_currentModName

---@class SPEC_distributor
---@field dirtyFlag number
---@field processingState number
---@field needsToBeTurnedOn boolean
---@field needsToBePoweredOn boolean
---@field processor Processor | nil
---@field canDischargeToGround boolean
---@field defaultCanDischargeToGround boolean
---@field canToggleDischargeToGround boolean
---@field canDischargeToGroundAnywhere boolean
---@field actionEvents table

---@class Distributor : Vehicle,FillUnit,FillVolume,TurnOnVehicle
---@field spec_distributor SPEC_distributor
Distributor = {
    PROCESSING_STATE_OFF = 0,
    PROCESSING_STATE_ON = 1,
    PROCESSING_STATE_NUM_BITS = 2
}

function Distributor.prerequisitesPresent(specializations)
    if SpecializationUtil.hasSpecialization(Dischargeable, specializations) then
        g_debugger:warning('Distributor.prerequisitesPresent() Vehicle has Dischargeable specialization, this could result in bugs/errors.')
    end

    return SpecializationUtil.hasSpecialization(FillUnit, specializations) and SpecializationUtil.hasSpecialization(FillVolume, specializations)
end

function Distributor.initSpecialization()
    g_configurationManager:addConfigurationType('distributor', 'Distributor', 'distributor', nil, nil, nil, ConfigurationUtil.SELECTOR_MULTIOPTION)

    local schema = Vehicle.xmlSchema
    local path = 'vehicle.distributor'
    schema:setXMLSpecializationType('Distributor')

    schema:register(XMLValueType.BOOL, path .. '#needsToBeTurnedOn', 'Vehicle needs to be turned on for machine to process input', true)
    schema:register(XMLValueType.BOOL, path .. '#needsToBePoweredOn', 'Vehicle needs to be powered on for machine to process input', true)
    schema:register(XMLValueType.BOOL, path .. '#defaultCanDischargeToGround', 'Set default canDischargeChargeToGround value when vehicle is loaded', false)
    schema:register(XMLValueType.BOOL, path .. '#canToggleDischargeToGround', 'Whether player can toggle discharge to ground or not', true)
    schema:register(XMLValueType.BOOL, path .. '#canDischargeToGroundAnywhere', '', false)

    Processor.registerXMLSchema(schema)
    ProcessInput.registerXMLSchema(schema)
    ProcessOutput.registerXMLSchema(schema)
    ProcessNode.registerXMLSchema(schema)

    schema:setXMLSpecializationType()
end

function Distributor.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'getCanChangeInput', Distributor.getCanChangeInput)
    SpecializationUtil.registerFunction(vehicleType, 'getCanProcess', Distributor.getCanProcess)
    SpecializationUtil.registerFunction(vehicleType, 'getIsProcessing', Distributor.getIsProcessing)
    SpecializationUtil.registerFunction(vehicleType, 'getProcessingState', Distributor.getProcessingState)
    SpecializationUtil.registerFunction(vehicleType, 'setProcessingState', Distributor.setProcessingState)

    SpecializationUtil.registerFunction(vehicleType, 'setProcessingInput', Distributor.setProcessingInput)
    SpecializationUtil.registerFunction(vehicleType, 'setCanDischargeToGround', Distributor.setCanDischargeToGround)
    SpecializationUtil.registerFunction(vehicleType, 'setDischargeNodeState', Distributor.setDischargeNodeState)

    SpecializationUtil.registerFunction(vehicleType, 'onSelectProcessInputCallback', Distributor.onSelectProcessInputCallback)
end

function Distributor.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", Distributor)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", Distributor)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", Distributor)

    SpecializationUtil.registerEventListener(vehicleType, "onTurnedOn", Distributor)
    SpecializationUtil.registerEventListener(vehicleType, "onTurnedOff", Distributor)

    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", Distributor)

    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", Distributor)
    SpecializationUtil.registerEventListener(vehicleType, 'onUpdateTick', Distributor)
    SpecializationUtil.registerEventListener(vehicleType, 'onDraw', Distributor)
    SpecializationUtil.registerEventListener(vehicleType, 'onActivate', Distributor)

    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", Distributor)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", Distributor)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", Distributor)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", Distributor)
end

function Distributor.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, "onDischargeStateChanged")
    SpecializationUtil.registerEvent(vehicleType, "onDischargeTargetObjectChanged")
end

---@param savegame SavegameObject
function Distributor:onLoad(savegame)
    ---@type SPEC_distributor
    local spec = {}
    local xmlFile = self.xmlFile
    local path = 'vehicle.distributor'

    spec.dirtyFlag = self:getNextDirtyFlag()
    spec.actionEvents = {}
    spec.processingState = Distributor.PROCESSING_STATE_OFF
    spec.needsToBeTurnedOn = xmlFile:getValue(path .. '#needsToBeTurnedOn', true)
    spec.needsToBePoweredOn = xmlFile:getValue(path .. '#needsToBePoweredOn', true)
    spec.defaultCanDischargeToGround = xmlFile:getValue(path .. '#defaultCanDischargeToGround', false)
    spec.canToggleDischargeToGround = xmlFile:getValue(path .. '#canToggleDischargeToGround', true)
    spec.canDischargeToGround = spec.defaultCanDischargeToGround
    spec.canDischargeToGroundAnywhere = xmlFile:getValue(path .. '#canDischargeToGroundAnywhere', false)

    self.spec_distributor = spec

    assert(xmlFile:hasProperty(path .. '.processor'), '(XML) Distributor missing processor element')

    spec.processor = SplitProcessor.new(self)

    if spec.processor:load(xmlFile, path .. '.processor') then
        g_debugger:info('Distributor processor loaded for vehicle: %s', self:getName())

        if self.isServer and savegame ~= nil then
            local inputIndex = savegame.xmlFile:getInt(savegame.key .. '.distributor#inputIndex', 1)
            spec.processor:setCurrentInputIndex(inputIndex)
        end
    else
        g_debugger:error('Failed to load distributor processor')
    end
end

function Distributor:onLoadFinished()
    local spec = self.spec_distributor

    if spec.processor ~= nil then
        local input = spec.processor:getCurrentInput()

        if input ~= nil then
            input:onSelect()
        elseif #spec.processor.inputs > 0 then
            if self.isServer then
                self:setProcessingInput(1)
            end
        end
    end
end

---@param xmlFile XMLFile
---@param key string
function Distributor:saveToXMLFile(xmlFile, key)
    local spec = self.spec_distributor
    key = key:gsub('.' .. modName, '')


    if spec.processor ~= nil then
        local input = spec.processor:getCurrentInput()

        if input ~= nil then
            xmlFile:setInt(key .. '#inputIndex', input.index)
        end
    end
end

function Distributor:onDelete()
    local spec = self.spec_distributor

    if g_debugger.distributor == self then
        g_debugger:setDistributor()
    end

    if spec.processor then
        spec.processor:onDelete()
        spec.processor = nil
    end
end

function Distributor:onActivate()
    g_debugger:setDistributor(self)
end

function Distributor:onTurnedOn()
    local spec = self.spec_distributor

    if spec.needsToBeTurnedOn then
        self:setProcessingState(Distributor.PROCESSING_STATE_ON)
    end
end

function Distributor:onTurnedOff()
    local spec = self.spec_distributor

    if spec.needsToBeTurnedOn then
        self:setProcessingState(Distributor.PROCESSING_STATE_OFF)
    end
end

function Distributor:onUpdate(...)
    local spec = self.spec_distributor

    if spec.processor ~= nil then
        spec.processor:onUpdate(...)
    end
end

function Distributor:onUpdateTick(...)
    local spec = self.spec_distributor

    if spec.processor ~= nil then
        spec.processor:onUpdateTick(...)
    end
end

function Distributor:onSelectProcessInputCallback(inputIndex)
    if inputIndex ~= nil then
        self:setProcessingInput(inputIndex)
    end
end

---@return boolean
function Distributor:getCanProcess()
    local spec = self.spec_distributor

    if spec.needsToBePoweredOn and not self:getIsPowered() then
        return false
    end

    if spec.needsToBeTurnedOn and not self:getIsTurnedOn() then
        return false
    end

    return true
end

---@return boolean
function Distributor:getCanChangeInput()
    local spec = self.spec_distributor

    local fillLevel = spec.processor:getCurrentInputFillLevel()

    return fillLevel < 0.1
end

---@return boolean
function Distributor:getIsProcessing()
    local spec = self.spec_distributor

    return spec.processingState == Distributor.PROCESSING_STATE_ON
end

---@return number
function Distributor:getProcessingState()
    local spec = self.spec_distributor

    return spec.processingState
end

---@param state number
---@param noEventSend boolean | nil
function Distributor:setProcessingState(state, noEventSend)
    local spec = self.spec_distributor

    if spec.processingState ~= state then
        SetProcessingStateEvent.sendEvent(self, state, noEventSend)

        spec.processingState = state

        if spec.processor ~= nil then
            if state == Distributor.PROCESSING_STATE_OFF then
                for _, node in ipairs(spec.processor.nodes) do
                    node:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, noEventSend)
                end
            end
        end
    end
end

function Distributor:setDischargeNodeState(nodeIndex, dischargeState, noEventSend)
    local spec = self.spec_distributor

    if spec.processor and nodeIndex ~= nil then
        local node = spec.processor.nodes[nodeIndex]

        if node ~= nil then
            node:setDischargeState(dischargeState, noEventSend)
        else
            g_debugger:error('Distributor:setDischargeNodeState() node index not found: %s', tostring(nodeIndex))
        end
    end
end

---@param canDischargeToGround boolean
---@param noEventSend boolean | nil
function Distributor:setCanDischargeToGround(canDischargeToGround, noEventSend)
    local spec = self.spec_distributor

    if spec.canDischargeToGround ~= canDischargeToGround then
        SetCanDischargeToGroundEvent.sendEvent(self, canDischargeToGround, noEventSend)

        spec.canDischargeToGround = canDischargeToGround

        if spec.processor ~= nil then
            for _, node in ipairs(spec.processor.nodes) do
                node:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, noEventSend)
            end
        end

        Distributor.updateActionEvents(self)
    end
end

function Distributor:setProcessingInput(index, noEventSend)
    local spec = self.spec_distributor

    if spec.processor ~= nil then
        if spec.processor.currentInputIndex ~= index then
            SetProcessingInputEvent.sendEvent(self, index, noEventSend)

            spec.processor:setCurrentInputIndex(index)
        end
    end
end

---@param isActiveForInput boolean
---@param isActiveForInputIgnoreSelection boolean
function Distributor:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_distributor

        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInputIgnoreSelection then
            local _, actionId = self:addActionEvent(spec.actionEvents, InputAction.IMPLEMENT_EXTRA4, self, Distributor.actionEventOpenDialog, false, true, false, true)
            g_inputBinding:setActionEventTextPriority(actionId, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventText(actionId, g_i18n:getText('DISTRIBUTOR_SELECT_INPUT'))

            if spec.canToggleDischargeToGround then
                _, actionId = self:addPoweredActionEvent(spec.actionEvents, InputAction.TOGGLE_TIPSTATE_GROUND, self, Distributor.actionEventToggleCanDischargeToGround, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(actionId, GS_PRIO_NORMAL)
            end

            Distributor.updateActionEvents(self)
        end
    end
end

function Distributor:updateActionEvents()
    local spec = self.spec_distributor
    local action = spec.actionEvents['DISTRIBUTOR_SELECT_INPUT']

    if action then
        g_inputBinding:setActionEventTextVisibility(action.actionEventId, spec.processor ~= nil)
    end

    action = spec.actionEvents[InputAction.TOGGLE_TIPSTATE_GROUND]

    if action then
        g_inputBinding:setActionEventTextVisibility(action.actionEventId, spec.canToggleDischargeToGround == true)

        if spec.canDischargeToGround then
            g_inputBinding:setActionEventText(action.actionEventId, g_i18n:getText('action_stopTipToGround'))
        else
            g_inputBinding:setActionEventText(action.actionEventId, g_i18n:getText('action_startTipToGround'))
        end
    end
end

function Distributor:actionEventOpenDialog()
    local spec = self.spec_distributor

    g_selectInputDialog:show(spec.processor, Distributor.onSelectProcessInputCallback, self)
end

function Distributor:actionEventToggleCanDischargeToGround()
    local spec = self.spec_distributor

    self:setCanDischargeToGround(not spec.canDischargeToGround)
end

--[[
    DEBUG
]]
function Distributor:onDebugDraw()
    local spec = self.spec_distributor
    local debugEnabled = true

    if debugEnabled and spec.processor ~= nil then
        spec.processor:onDebugDraw()
    end
end

function Distributor:onDraw()
    local spec = self.spec_distributor

    if spec.processor ~= nil then
        if (spec.needsToBeTurnedOn or spec.needsToBePoweredOn) and not self:getIsPowered() then
            return
        end

        local input = spec.processor:getCurrentInput()

        if input ~= nil then
            local node = self:getFillUnitRootNode(input.fillUnitIndex)

            if node ~= nil then
                g_debugger:drawTextAtNode(node, input.fillType.title, 0.014, { 0.83, 1, 0.83 }, 0.04)
            end
        end

        for _, node in ipairs(spec.processor.nodes) do
            local output = spec.processor.nodesByFillUnitIndex[node.fillUnitIndex]

            if output ~= nil then
                local fillType = output:getCurrentFillType()
                if fillType ~= nil then
                    g_debugger:drawTextAtNode(node.i3dNode, fillType.title, 0.0145, { 0, 0, 0, 0.7 }, 0.04)
                    g_debugger:drawTextAtNode(node.i3dNode, fillType.title, 0.014, { 0.8, 0.9, 1 }, 0.04)
                end
            end
        end
    end
end

--[[
    NETWORKING
]]
---@param streamId number
---@param connection Connection
function Distributor:onWriteStream(streamId, connection)
    local spec = self.spec_distributor

    if not connection:getIsServer() then
        streamWriteBool(streamId, spec.canDischargeToGround)
        streamWriteUIntN(streamId, spec.processingState, Distributor.PROCESSING_STATE_NUM_BITS)

        if spec.processor ~= nil then
            spec.processor:onWriteStream(streamId, connection)
        end
    end
end

---@param streamId number
---@param connection Connection
function Distributor:onReadStream(streamId, connection)
    local spec = self.spec_distributor

    if connection:getIsServer() then
        self:setCanDischargeToGround(streamReadBool(streamId), true)
        self:setProcessingState(streamReadUIntN(streamId, Distributor.PROCESSING_STATE_NUM_BITS), true)

        if spec.processor ~= nil then
            spec.processor:onReadStream(streamId, connection)
        end
    end
end

---@param streamId number
---@param connection Connection
---@param dirtyMask number
function Distributor:onWriteUpdateStream(streamId, connection, dirtyMask)
    local spec = self.spec_distributor

    if not connection:getIsServer() then
        if spec.processor ~= nil then
            if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
                spec.processor:onWriteUpdateStream(streamId, connection)
            end
        end
    end
end

---@param streamId number
---@param connection Connection
function Distributor:onReadUpdateStream(streamId, timestamp, connection)
    local spec = self.spec_distributor

    if connection:getIsServer() then
        if spec.processor ~= nil then
            if streamReadBool(streamId) then
                spec.processor:onReadUpdateStream(streamId, timestamp, connection)
            end
        end
    end
end
