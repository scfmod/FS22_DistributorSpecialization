---@class SplitProcessor : Processor
SplitProcessor = {}
local SplitProcessor_mt = Class(SplitProcessor, Processor)

---@return SplitProcessor
function SplitProcessor.new(vehicle, mt)
    ---@type SplitProcessor
    ---@diagnostic disable-next-line: assign-type-mismatch
    local self = Processor.new(vehicle, mt or SplitProcessor_mt)
    return self
end

---@param xmlFile XMLFile
---@param path string
---@return boolean
function SplitProcessor:load(xmlFile, path)
    return Processor.load(self, xmlFile, path)
end

---@param dt number
---@return number
function SplitProcessor:process(dt)
    local input = self:getCurrentInput()

    if input == nil then
        return 0
    end

    local fillLevel, fillUnitIndex = input:getFillLevel()

    if fillLevel == nil or fillLevel == 0 then
        return 0
    end

    local processingSpeed = self.processingSpeed
    local chunkSize = (processingSpeed / 1000) * dt
    local liters = math.min(chunkSize, fillLevel)

    liters = input:getAvailableOutputCapacityFromLiters(liters)

    if liters == 0 then
        return 0
    end

    local processedLiters = 0

    for _, output in ipairs(input.outputs) do
        local delta = output:addFilllevel(liters * output.ratio)
        processedLiters = processedLiters + delta

        output.debugProcessed = output.debugProcessed + delta
    end

    if processedLiters == 0 then
        return 0
    end

    return self.vehicle:addFillUnitFillLevel(self.vehicle:getOwnerFarmId(), fillUnitIndex, -processedLiters, input.fillTypeIndex, ToolType.UNDEFINED)
end
