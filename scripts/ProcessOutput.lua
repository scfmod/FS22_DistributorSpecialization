---@class ProcessOutput
---@field input ProcessInput
---@field index number
---@field name string | nil
---@field vehicle Distributor
---@field fillUnit FillUnitObject
---@field fillUnitIndex number
---@field fillType FillTypeObject
---@field fillTypeName string
---@field fillTypeIndex number
---@field ratio number
---
---@field debugProcessed number
ProcessOutput = {}
local ProcessOutput_mt = Class(ProcessOutput)

---@param index number
---@param input ProcessInput
---@param mt any
---@return ProcessOutput
function ProcessOutput.new(index, input, mt)
    ---@type ProcessOutput
    local self = setmetatable({}, mt or ProcessOutput_mt)

    self.index = index
    self.input = input
    self.vehicle = input.vehicle
    self.debugProcessed = 0

    return self
end

---@param xmlFile XMLFile
---@param path string
---@return boolean
function ProcessOutput:load(xmlFile, path)
    self.name = xmlFile:getValue(path .. '#name')
    self.ratio = xmlFile:getValue(path .. '#ratio')
    self.fillUnitIndex = xmlFile:getValue(path .. '#fillUnitIndex')
    ---@diagnostic disable-next-line: assign-type-mismatch
    self.fillUnit = self.vehicle:getFillUnitByIndex(self.fillUnitIndex)

    if self.fillUnit == nil then
        g_debugger:error('ProcessOutput:load() Failed to find vehicle fillUnit: %i', self.fillUnitIndex)
        return false
    end

    self.fillTypeName = xmlFile:getValue(path .. '#fillType')
    self.fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(self.fillTypeName)
    self.fillType = g_fillTypeManager:getFillTypeByIndex(self.fillTypeIndex)

    if not self.fillTypeIndex then
        g_debugger:error('ProcessOutput:load() Unknown fillType: %s', self.fillTypeName)
        return false
    end

    return true
end

function ProcessOutput:getFillType()
    return self.fillType
end

---@return number
function ProcessOutput:getFillLevel()
    local fillLevel = self.vehicle:getFillUnitFillLevel(self.fillUnitIndex)

    if fillLevel == nil then
        return 0
    end

    return fillLevel
end

---@return number
function ProcessOutput:addFilllevel(fillLevelDelta)
    return self.vehicle:addFillUnitFillLevel(self.vehicle:getOwnerFarmId(), self.fillUnitIndex, fillLevelDelta, self.fillTypeIndex, ToolType.UNDEFINED)
end

---@return number
function ProcessOutput:getFreeCapacity()
    local freeCapacity = self.vehicle:getFillUnitFreeCapacity(self.fillUnitIndex)

    if freeCapacity == nil then
        return 0
    end

    return freeCapacity
end

function ProcessOutput:getFreeInputCapacity()
    return self:getFreeCapacity() * self.ratio
end

---@param x number
---@param y number
---@return number
function ProcessOutput:onDebugDraw(x, y)
    local function text(str)
        renderText(x, y, 0.014, str)
        y = y - 0.014
    end

    text('Output: ' .. self.fillTypeName)
    text('debugProcessed: ' .. tostring(self.debugProcessed))

    return y
end

function ProcessOutput:onSelect()
    self.fillUnit.supportedFillTypes = {}
    self.fillUnit.supportedFillTypes[self.fillTypeIndex] = true

    self.vehicle:setFillUnitFillType(self.fillUnitIndex, self.fillTypeIndex)

    self.debugProcessed = 0
end

function ProcessOutput:getAvailableInputCapacity(inputLiters)
    local freeCapacity = self:getFreeCapacity()
    local freeInputCapacity = freeCapacity * self.ratio
    local litersWithRatio = inputLiters * self.ratio

    if freeInputCapacity < litersWithRatio then
        local inputThresholdRatio = freeInputCapacity / litersWithRatio
        local inputThresholdLiters = inputLiters * inputThresholdRatio

        return inputThresholdLiters / self.ratio, inputThresholdLiters, inputThresholdRatio
    end

    return freeCapacity, freeInputCapacity, 1
end

---@param schema XMLSchema
function ProcessOutput.registerXMLSchema(schema)
    local path = 'vehicle.distributor.processor.fillTypeMappings.input(?).output(?)'

    schema:register(XMLValueType.STRING, path .. '#fillType', 'Output fill type name', nil, true)
    schema:register(XMLValueType.INT, path .. '#fillUnitIndex', 'Output fill unit index', nil, true)
    schema:register(XMLValueType.FLOAT, path .. '#ratio', 'Output ratio from input', nil, true)
    schema:register(XMLValueType.STRING, path .. '#name', 'Output name for GUI')
end
