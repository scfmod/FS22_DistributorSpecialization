--[[

    FS22_DistributorSpecialization

    author: scfmod
    url: httsp://github.com/scfmod/FS22_DistributorSpecialization

    If you distribute this mod, always include this info.

    AND DO NOT UPLOAD IT TO MONATERY UPLOAD SERVICES.
    THIS CODE IS AVAILABLE TO ANYONE FOR FREE AND YOU CAN USE
    IT TO LEARN, FORK AND SPREAD THE KNOWLEDGE.

]]
local modFolder = g_currentModDirectory

---@param path string
local function load(path)
    source(modFolder .. path)
end

load('scripts/debug/Debugger.lua')

load('scripts/gui/elements/InputsTableElement.lua')
load('scripts/gui/elements/OutputsTableElement.lua')
load('scripts/gui/dialogs/SelectInputDialog.lua')

load('scripts/Processor.lua')
load('scripts/ProcessInput.lua')
load('scripts/ProcessOutput.lua')
load('scripts/ProcessNode.lua')

load('scripts/processors/SplitProcessor.lua')
-- load('scripts/processors/CombineProcessor.lua')

g_specializationManager:addSpecialization('distributor', 'Distributor', modFolder .. 'scripts/specializations/Distributor.lua')

load('scripts/events/SetCanDischargeToGroundEvent.lua')
load('scripts/events/SetDischargeNodeState.lua')
load('scripts/events/SetProcessingInputEvent.lua')
load('scripts/events/SetProcessingStateEvent.lua')

if g_debugger.exportSpecializationSchema then
    load('scripts/utils/exportSpecializationSchema.lua')
end
