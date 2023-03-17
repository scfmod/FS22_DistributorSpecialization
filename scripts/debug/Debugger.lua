--[[

    TODO:
    - Replace all Logging.* functions used to Debugger.*


]]
---@class Debugger
---@field showDebugs boolean
---@field showErrors boolean
---@field showInfos boolean
---@field showWarnings boolean
---@field showGuiDebug boolean
---@field drawDebug boolean
---@field distributor Distributor | nil
---@field exportSpecializationSchema boolean
Debugger = {}
local Debugger_mt = Class(Debugger)

---@return Debugger
function Debugger.new()
    ---@type Debugger
    local self = setmetatable({}, Debugger_mt)

    self.showDebugs = false
    self.showErrors = true
    self.showInfos = true
    self.showWarnings = true
    self.drawDebug = false
    self.exportSpecializationSchema = false

    return self
end

---@param distributor Distributor | nil
function Debugger:setDistributor(distributor)
    self.distributor = distributor
end

function Debugger:debug(message, ...)
    if self.showDebugs then
        print(('  [DistributorSpecialization] Debug: ' .. message):format(...))
    end
end

---@param message string
---@param ... any
function Debugger:info(message, ...)
    if self.showInfos then
        print(('  [DistributorSpecialization] Info: ' .. message):format(...))
    end
end

---@param message string
---@param ... any
function Debugger:error(message, ...)
    if self.showErrors then
        printError(('  [DistributorSpecialization] Error: ' .. message):format(...))
    end
end

---@param message string
---@param ... any
function Debugger:warning(message, ...)
    if self.showWarnings then
        printWarning((' [DistributorSpecialization] Warning: ' .. message):format(...))
    end
end

function Debugger:onDraw()
    if self.drawDebug and self.distributor ~= nil then
        setTextBold(false)
        Distributor.onDebugDraw(self.distributor)
    end
end

function Debugger:drawTextAtNode(node, text, textSize, color, textOffset)
    local x, y, z = getWorldTranslation(node)

    Utils.renderTextAtWorldPosition(x, y, z, text, textSize or 0.02, textOffset, color)
end

---@diagnostic disable-next-line: lowercase-global
g_debugger = Debugger.new()

if g_debugger.drawDebug then
    BaseMission.draw = Utils.appendedFunction(BaseMission.draw, function()
        g_debugger:onDraw()
    end)
end
