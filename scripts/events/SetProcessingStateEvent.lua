---@class SetProcessingStateEvent : Event
---@field state number
---@field vehicle Distributor
SetProcessingStateEvent = {}
local SetProcessingStateEvent_mt = Class(SetProcessingStateEvent, Event)

InitEventClass(SetProcessingStateEvent, 'SetProcessingStateEvent')

---@return SetProcessingStateEvent
function SetProcessingStateEvent.emptyNew()
    local self = Event.new(SetProcessingStateEvent_mt)
    return self
end

---@param vehicle Distributor
---@param state number
---@return SetProcessingStateEvent
function SetProcessingStateEvent.new(vehicle, state)
    local self = SetProcessingStateEvent.emptyNew()

    self.vehicle = vehicle
    self.state = state

    return self
end

---@param streamId number
---@param connection Connection
function SetProcessingStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.state, Distributor.PROCESSING_STATE_NUM_BITS)
end

---@param streamId number
---@param connection Connection
function SetProcessingStateEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.state = streamReadUIntN(streamId, Distributor.PROCESSING_STATE_NUM_BITS)

    self:run(connection)
end

---@param connection Connection
function SetProcessingStateEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:setProcessingState(self.state, true)
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(SetProcessingStateEvent.new(self.vehicle, self.state), nil, connection, self.vehicle)
    end
end

---@param vehicle Distributor
---@param state number
---@param noEventSend boolean | nil
function SetProcessingStateEvent.sendEvent(vehicle, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        local event = SetProcessingStateEvent.new(vehicle, state)

        if g_server ~= nil then
            g_server:broadcastEvent(event, nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(event)
        end
    end
end
