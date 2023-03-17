---@class SetCanDischargeToGroundEvent : Event
---@field vehicle Distributor
---@field canDischargeToGround boolean
SetCanDischargeToGroundEvent = {}
local SetCanDischargeToGroundEvent_mt = Class(SetCanDischargeToGroundEvent, Event)

InitEventClass(SetCanDischargeToGroundEvent, 'SetCanDischargeToGroundEvent')


---@return SetCanDischargeToGroundEvent
function SetCanDischargeToGroundEvent.emptyNew()
    local self = Event.new(SetCanDischargeToGroundEvent_mt)
    return self
end

---@param vehicle any
---@param canDischargeToGround any
---@return SetCanDischargeToGroundEvent
function SetCanDischargeToGroundEvent.new(vehicle, canDischargeToGround)
    local self = SetCanDischargeToGroundEvent.emptyNew()

    self.vehicle = vehicle
    self.canDischargeToGround = canDischargeToGround

    return self
end

---@param streamId number
---@param connection Connection
function SetCanDischargeToGroundEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.canDischargeToGround)
end

---@param streamId number
---@param connection Connection
function SetCanDischargeToGroundEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.canDischargeToGround = streamReadBool(streamId)

    self:run(connection)
end

---@param connection Connection
function SetCanDischargeToGroundEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:setCanDischargeToGround(self.canDischargeToGround, true)
    end

    if not connection:getIsServer() then
        local event = SetCanDischargeToGroundEvent.new(self.vehicle, self.canDischargeToGround)
        g_server:broadcastEvent(event, nil, connection, self.vehicle)
    end
end

---@param vehicle Distributor
---@param canDischargeToGround boolean
---@param noEventSend boolean | nil
function SetCanDischargeToGroundEvent.sendEvent(vehicle, canDischargeToGround, noEventSend)
    if noEventSend == nil or noEventSend == false then
        local event = SetCanDischargeToGroundEvent.new(vehicle, canDischargeToGround)

        if g_server ~= nil then
            g_server:broadcastEvent(event, nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(event)
        end
    end
end
