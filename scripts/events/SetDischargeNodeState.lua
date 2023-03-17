---@class SetDischargeNodeState : Event
---@field vehicle Distributor
---@field nodeIndex number
---@field dischargeState number
SetDischargeNodeState = {}
local SetDischargeNodeState_mt = Class(SetDischargeNodeState, Event)

InitEventClass(SetDischargeNodeState, 'SetDischargeNodeState')

---@return SetDischargeNodeState
function SetDischargeNodeState.emptyNew()
    local self = Event.new(SetDischargeNodeState_mt)
    return self
end

---@param vehicle Distributor
---@param nodeIndex number
---@param dischargeState number
---@return SetDischargeNodeState
function SetDischargeNodeState.new(vehicle, nodeIndex, dischargeState)
    local self = SetDischargeNodeState.emptyNew()

    self.vehicle = vehicle
    self.nodeIndex = nodeIndex
    self.dischargeState = dischargeState

    return self
end

---@param streamId number
---@param connection Connection
function SetDischargeNodeState:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.nodeIndex, ProcessNode.NUM_BITS_INDEX)
    streamWriteUIntN(streamId, self.dischargeState, Dischargeable.SEND_NUM_BITS_DISCHARGE_STATE)
end

---@param streamId number
---@param connection Connection
function SetDischargeNodeState:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.nodeIndex = streamReadUIntN(streamId, ProcessNode.NUM_BITS_INDEX)
    self.dischargeState = streamReadUIntN(streamId, Dischargeable.SEND_NUM_BITS_DISCHARGE_STATE)

    self:run(connection)
end

---@param connection Connection
function SetDischargeNodeState:run(connection)
    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:setDischargeNodeState(self.nodeIndex, self.dischargeState, true)
    end

    if not connection:getIsServer() then
        local event = SetDischargeNodeState.new(self.vehicle, self.nodeIndex, self.dischargeState)
        g_server:broadcastEvent(event, nil, connection, self.vehicle)
    end
end

---@param vehicle Distributor
---@param nodeIndex number
---@param dischargeState number
---@param noEventSend boolean | nil
function SetDischargeNodeState.sendEvent(vehicle, nodeIndex, dischargeState, noEventSend)
    if noEventSend == nil or noEventSend == false then
        local event = SetDischargeNodeState.new(vehicle, nodeIndex, dischargeState)

        if g_server ~= nil then
            g_server:broadcastEvent(event, nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(event)
        end
    end
end
