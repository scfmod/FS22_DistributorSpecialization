---@class SetProcessingInputEvent : Event
---@field vehicle Distributor
---@field inputIndex number
SetProcessingInputEvent = {}
local SetProcessingInputEvent_mt = Class(SetProcessingInputEvent, Event)

InitEventClass(SetProcessingInputEvent, 'SetProcessingInputEvent')

---@return SetProcessingInputEvent
function SetProcessingInputEvent.emptyNew()
    local self = Event.new(SetProcessingInputEvent_mt)
    return self
end

---@param vehicle Distributor
---@param inputIndex number
---@return SetProcessingInputEvent
function SetProcessingInputEvent.new(vehicle, inputIndex)
    local self = SetProcessingInputEvent.emptyNew()

    self.vehicle = vehicle
    self.inputIndex = inputIndex

    return self
end

---@param streamId number
---@param connection Connection
function SetProcessingInputEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.inputIndex, ProcessInput.INDEX_NUM_BITS)
end

---@param streamId number
---@param connection Connection
function SetProcessingInputEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.inputIndex = streamReadUIntN(streamId, ProcessInput.INDEX_NUM_BITS)

    self:run(connection)
end

---@param connection Connection
function SetProcessingInputEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:setProcessingInput(self.inputIndex, true)
    end

    if not connection:getIsServer() then
        local event = SetProcessingInputEvent.new(self.vehicle, self.inputIndex)
        g_server:broadcastEvent(event, nil, connection, self.vehicle)
    end
end

---@param vehicle Distributor
---@param inputIndex number
---@param noEventSend boolean | nil
function SetProcessingInputEvent.sendEvent(vehicle, inputIndex, noEventSend)
    if noEventSend == nil or noEventSend == false then
        local event = SetProcessingInputEvent.new(vehicle, inputIndex)

        if g_server ~= nil then
            g_server:broadcastEvent(event, nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(event)
        end
    end
end
