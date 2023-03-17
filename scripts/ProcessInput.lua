---@class ProcessInput
---@field index number
---@field name string | nil
---@field processor Processor
---@field fillType FillTypeObject
---@field fillTypeName string
---@field fillTypeIndex number
---@field fillUnit FillUnitObject
---@field fillUnitIndex number
---@field outputs ProcessOutput[]
---@field outputsByFillUnitIndex table<number, ProcessOutput>
---@field vehicle Distributor
ProcessInput = {
    INDEX_NUM_BITS = 4
}
local ProcessInput_mt = Class(ProcessInput)

---@param index number
---@param processor Processor
---@param mt any
---@return ProcessInput
function ProcessInput.new(index, processor, mt)
    ---@type ProcessInput
    local self = setmetatable({}, mt or ProcessInput_mt)

    self.index = index
    self.processor = processor
    self.vehicle = processor.vehicle
    self.fillUnitIndex = processor.fillUnitIndex
    self.fillUnit = processor.fillUnit
    self.outputs = {}
    self.outputsByFillUnitIndex = {}

    return self
end

---@param xmlFile XMLFile
---@param path string
---@return boolean
function ProcessInput:load(xmlFile, path)
    self.name = xmlFile:getValue(path .. '#name')
    self.fillTypeName = xmlFile:getValue(path .. '#fillType')
    self.fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(self.fillTypeName)
    self.fillType = g_fillTypeManager:getFillTypeByIndex(self.fillTypeIndex)

    if not self.fillTypeIndex then
        g_debugger:error('ProcessInput:load() Unknown fillType: %s', self.fillTypeName)
        return false
    end

    xmlFile:iterate(path .. '.output', function(_, key)
        local output = ProcessOutput.new(#self.outputs + 1, self)

        if output:load(xmlFile, key) then
            g_debugger:debug('ProcessInput:load() found output: %s', output.fillTypeName)

            if self.outputsByFillUnitIndex[output.fillUnitIndex] == nil then
                table.insert(self.outputs, output)
                self.outputsByFillUnitIndex[output.fillUnitIndex] = output
            else
                g_debugger:warning('Processor:load() duplicate output with fillUnitIndex: %i', output.fillUnitIndex)
            end
        end
    end)

    if #self.outputs == 0 then
        g_debugger:warning('ProcessInput:load() No outputs found for input: %s', self.fillTypeName)
        return false
    end

    return true
end

function ProcessInput:getFillType()
    return self.fillType
end

function ProcessInput:onSelect()
    self.fillUnit.supportedFillTypes = {}
    self.fillUnit.supportedFillTypes[self.fillTypeIndex] = true

    self.vehicle:setFillUnitFillType(self.fillUnitIndex, self.fillTypeIndex)

    for _, output in ipairs(self.outputs) do
        output:onSelect()
    end
end

---@param fillUnitIndex number | nil
---@return ProcessOutput | nil
function ProcessInput:getOutputFromFillUnitIndex(fillUnitIndex)
    if fillUnitIndex ~= nil then
        return self.outputsByFillUnitIndex[fillUnitIndex]
    end
end

---@return number fillLevel
---@return number fillUnitIndex
function ProcessInput:getFillLevel()
    local fillUnitIndex = self.processor.fillUnitIndex
    local fillLevel = self.vehicle:getFillUnitFillLevel(fillUnitIndex)

    if fillLevel == nil then
        fillLevel = 0.0
    end

    return fillLevel, fillUnitIndex
end

function ProcessInput:getAvailableOutputCapacityFromLiters(liters)
    local minimumInputThresholdRatio = 1

    for _, output in ipairs(self.outputs) do
        local availableInputCapacity, availableInputCapacityWithRatio, inputThresholdRatio = output:getAvailableInputCapacity(liters)

        if availableInputCapacity == 0 or availableInputCapacityWithRatio == 0 then
            return 0
        end

        minimumInputThresholdRatio = math.min(minimumInputThresholdRatio, inputThresholdRatio)
    end

    return liters * minimumInputThresholdRatio
end

--[[
    DEBUG
]]
---@param x number
---@param y number
---@return number
function ProcessInput:onDebugDraw(x, y)
    local function text(str)
        renderText(x, y, 0.014, str)
        y = y - 0.014
    end

    local totalOutputProcessed = 0

    for _, output in ipairs(self.outputs) do
        y = output:onDebugDraw(x, y) - 0.01
        totalOutputProcessed = totalOutputProcessed + output.debugProcessed
    end


    text('totalOutputProcessed: ' .. tostring(totalOutputProcessed))

    return y
end

--[[
    SCHEMA
]]
---@param schema XMLSchema
function ProcessInput.registerXMLSchema(schema)
    local path = 'vehicle.distributor.processor.fillTypeMappings.input(?)'

    schema:register(XMLValueType.STRING, path .. '#fillType', 'Input fill type name', nil, true)
    schema:register(XMLValueType.STRING, path .. '#name', 'Input name for GUI')
end
