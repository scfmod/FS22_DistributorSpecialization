---@class Processor
---@field vehicle Distributor
---@field currentInputIndex number
---@field currentInput ProcessInput | nil
---@field nodes ProcessNode[]
---@field nodesByFillUnitIndex table<number, ProcessNode>
---@field inputs ProcessInput[]
---@field inputsByFillTypeIndex table<number, ProcessInput>
---
---@field fillUnit FillUnitObject
---@field fillUnitIndex number
---@field processingSpeed number
Processor = {}
local Processor_mt = Class(Processor)

Processor.NUM_BITS_INPUT_INDEX = 4

---@param vehicle Distributor
---@param mt any
---@return Processor
function Processor.new(vehicle, mt)
    ---@type Processor
    local self = setmetatable({}, mt or Processor_mt)

    self.vehicle = vehicle
    self.nodes = {}
    self.nodesByFillUnitIndex = {}
    self.inputs = {}
    self.inputsByFillTypeIndex = {}

    self.currentInputIndex = 0
    self.currentInput = nil

    return self
end

---@return ProcessInput | nil
function Processor:getCurrentInput()
    return self.currentInput
end

---@param index number
---@return boolean
function Processor:setCurrentInputIndex(index)
    if index == 0 or index == nil or self.currentInputIndex == index then
        return false
    elseif index > #self.inputs then
        index = 1
    end

    local input = self.inputs[index]

    if input ~= nil and self.currentInput ~= input then
        input:onSelect()

        self.currentInputIndex = index
        self.currentInput = input

        return true
    end

    return false
end

---@param xmlFile XMLFile
---@param path string
---@return boolean
function Processor:load(xmlFile, path)
    self.processingSpeed = xmlFile:getValue(path .. '#processingSpeed', 400)
    self.fillUnitIndex = xmlFile:getValue(path .. '#fillUnitIndex')
    ---@diagnostic disable-next-line: assign-type-mismatch
    self.fillUnit = self.vehicle:getFillUnitByIndex(self.fillUnitIndex)

    if self.fillUnit == nil then
        g_debugger:error('Processor:load() Failed to find vehicle fillUnit: %i', self.fillUnitIndex)
        return false
    end

    self:loadInputs(xmlFile, path)

    if #self.inputs == 0 then
        g_debugger:error('Processor:load() Failed to find any inputs')
        return false
    elseif self.vehicle.isServer then
        self:setCurrentInputIndex(1)
    end

    self:loadNodes(xmlFile, path)

    if #self.nodes == 0 then
        g_debugger:warning('Processor:load() Failed to find any nodes')
        return false
    end

    return true
end

---@param xmlFile XMLFile
---@param path string
function Processor:loadNodes(xmlFile, path)
    xmlFile:iterate(path .. '.nodes.node', function(_, key)
        local node = ProcessNode.new(#self.nodes + 1, self)

        if node:load(xmlFile, key) then
            g_debugger:debug('Processor:loadNodes() found node: %i', node.fillUnitIndex)

            if self.nodesByFillUnitIndex[node.fillUnitIndex] == nil then
                table.insert(self.nodes, node)
                self.nodesByFillUnitIndex[node.fillUnitIndex] = node
            else
                g_debugger:error('Processor:loadNodes() duplicate node fillUnitIndex: %i', node.fillUnitIndex)
            end
        end
    end)
end

---@param xmlFile XMLFile
---@param path string
function Processor:loadInputs(xmlFile, path)
    xmlFile:iterate(path .. '.fillTypeMappings.input', function(_, key)
        local input = ProcessInput.new(#self.inputs + 1, self)

        if input:load(xmlFile, key) then
            g_debugger:debug('Processor:loadInputs() found input: %s', input.fillTypeName)

            if self.inputsByFillTypeIndex[input.fillTypeIndex] == nil then
                table.insert(self.inputs, input)
                self.inputsByFillTypeIndex[input.fillTypeIndex] = input
            else
                g_debugger:error('Processor:loadInputs() duplicate input: %s', input.fillTypeName)
            end
        end
    end)
end

---@return number
---@return number | nil fillUnitIndex
function Processor:getCurrentInputFillLevel()
    local input = self:getCurrentInput()

    if input ~= nil then
        return input:getFillLevel()
    end

    return 0
end

---@param dt number
---@return number
function Processor:process(dt)
    assert(dt == nil, 'Processor:process() function must be implemented by inherited class')
    return 0
end

function Processor:onUpdate(dt)
    for _, node in ipairs(self.nodes) do
        node:onUpdate(dt)
    end
end

function Processor:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    for _, node in ipairs(self.nodes) do
        node:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    end

    if self.vehicle.isServer and self.vehicle:getCanProcess() then
        local processedLiters = self:process(dt)
        self:onAfterProcessed(processedLiters)
    end
end

---@param processedLiters number
function Processor:onAfterProcessed(processedLiters)
    local spec = self.vehicle.spec_distributor

    if processedLiters > 0 and spec.processingState == Distributor.PROCESSING_STATE_OFF then
        self.vehicle:setProcessingState(Distributor.PROCESSING_STATE_ON)
    end
end

function Processor:onDelete()
    for _, node in ipairs(self.nodes) do
        node:onDelete()
    end

    self.nodes = {}
end

---@param fillUnitIndex number
---@return ProcessNode | nil
function Processor:getNodeByFillUnitIndex(fillUnitIndex)
    return self.nodesByFillUnitIndex[fillUnitIndex]
end

--[[
    NETWORKING
]]
---@param streamId number
---@param connection Connection
function Processor:onWriteStream(streamId, connection)
    streamWriteUIntN(streamId, self.currentInputIndex, Processor.NUM_BITS_INPUT_INDEX)


    for _, node in ipairs(self.nodes) do
        if streamWriteBool(streamId, node.isEffectActiveSent) then
            streamWriteUIntN(streamId, MathUtil.clamp(math.floor(node.dischargeDistanceSent / node.maxDistance * 255), 1, 255), 8)
        end

        streamWriteUIntN(streamId, node.currentDischargeState, Dischargeable.SEND_NUM_BITS_DISCHARGE_STATE)
    end
end

---@param streamId number
---@param connection Connection
function Processor:onReadStream(streamId, connection)
    self.vehicle:setProcessingInput(streamReadUIntN(streamId, Processor.NUM_BITS_INPUT_INDEX), true)


    for _, node in ipairs(self.nodes) do
        if streamReadBool(streamId) then
            local distance = streamReadUIntN(streamId, 8) * node.maxDistance / 255
            node.dischargeDistance = distance
            node:setDischargeEffectActive(true, false)
            node:setDischargeEffectDistance(distance)
        else
            node:setDischargeEffectActive(false)
        end

        local dischargeState = streamReadUIntN(streamId, Dischargeable.SEND_NUM_BITS_DISCHARGE_STATE)
        node:setDischargeState(dischargeState, true)
    end
end

---@param streamId number
---@param connection Connection
function Processor:onWriteUpdateStream(streamId, connection)
    for _, node in ipairs(self.nodes) do
        if streamWriteBool(streamId, node.isEffectActiveSent) then
            streamWriteUIntN(streamId, MathUtil.clamp(math.floor(node.dischargeDistanceSent / node.maxDistance * 255), 1, 255), 8)
            streamWriteUIntN(streamId, node:getCurrentFillTypeIndex(), FillTypeManager.SEND_NUM_BITS)
        end
    end
end

---@param streamId number
---@param connection Connection
function Processor:onReadUpdateStream(streamId, timestamp, connection)
    for _, node in ipairs(self.nodes) do
        if streamReadBool(streamId) then
            local distance = streamReadUIntN(streamId, 8) * node.maxDistance / 255
            node.dischargeDistance = distance
            local fillTypeIndex = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)

            node:setDischargeEffectActive(true, false, fillTypeIndex)
            node:setDischargeEffectDistance(distance)
        else
            node:setDischargeEffectActive(false)
        end
    end
end

--[[
    SCHEMA
]]
---@param schema XMLSchema
function Processor.registerXMLSchema(schema)
    local path = 'vehicle.distributor.processor'

    schema:register(XMLValueType.FLOAT, path .. '#processingSpeed', 'Processing input speed in liters/second', 400, true)
    schema:register(XMLValueType.INT, path .. '#fillUnitIndex', 'Input fillUnit index', nil, true)
end

--[[
    DEBUG
]]
function Processor:onDebugDraw()
    local spec = self.vehicle.spec_distributor

    local input = self:getCurrentInput()

    local n_x = 0.25
    local n_y = 0.75

    local state

    if spec.processingState == Distributor.PROCESSING_STATE_ON then
        state = 'ON'
    elseif spec.processingState == Distributor.PROCESSING_STATE_OFF then
        state = 'OFF'
    end

    renderText(n_x, n_y + 0.05, 0.014, ('Processing state: %s (%s)'):format(tostring(state), tostring(spec.processingState)))

    for _, node in ipairs(self.nodes) do
        n_y = node:onDebugDraw(n_x, n_y) - 0.01
    end

    n_x = 0.7
    n_y = 0.75

    if input ~= nil then
        n_y = input:onDebugDraw(n_x, n_y) - 0.01
    end
end
