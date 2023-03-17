---@class OutputsTableElement : TableElement
---@field target any
---@field tableRows TableElementRow[]
---@field dataView TableElementDataRow<FillTypeObject>[]
---@field data TableElementDataRow<FillTypeObject>[]
---@field dataBindings table<string, string>
OutputsTableElement = {}

local OutputsTableElement_mt = Class(OutputsTableElement, TableElement)

---@param target any
---@param mt any
---@return OutputsTableElement
function OutputsTableElement.new(target, mt)
    ---@type OutputsTableElement
    local self = TableElement.new(target, mt or OutputsTableElement_mt)

    self.dataBindings = {}
    self.doesFocusScrollList = false
    self.updateSelectionOnOpen = false

    return self
end

function OutputsTableElement:initialize(dataBindings)
    TableElement.initialize(self)
    self.dataBindings = dataBindings
end

---@param input ProcessInput | nil
function OutputsTableElement:updateData(input)
    self:clearData()

    if input ~= nil then
        for _, output in ipairs(input.outputs) do
            local dataRow = self:buildDataRow(output)
            self:addRow(dataRow)
        end
    end

    self:updateView()
end

---@param output ProcessOutput
---@return TableElementDataRow<FillTypeObject>
function OutputsTableElement:buildDataRow(output)
    ---@type TableElementDataRow<FillTypeObject>
    local row = TableElement.DataRow.new(output.index, self.dataBindings)

    -- local imageCell = row.columnCells[self.dataBindings['image']]
    local textCell = row.columnCells[self.dataBindings['text']]
    local fillType = output:getFillType()

    row.itemData = fillType
    textCell.text = fillType.title

    return row
end

---@param tableRow TableElementRow
---@return BitmapElement | nil
function OutputsTableElement:getImageElement(tableRow)
    if tableRow.rowElement.elements[1] then
        ---@diagnostic disable-next-line: return-type-mismatch
        return tableRow.rowElement.elements[1].elements[1]
    end
end

function OutputsTableElement:updateRows()
    TableElement.updateRows(self)

    ---@param tableRow TableElementRow
    ---@param dataRow TableElementDataRow<FillTypeObject>
    local function setImage(tableRow, dataRow)
        local imageElement = self:getImageElement(tableRow)
        local fillType = dataRow.itemData

        if imageElement ~= nil and fillType ~= nil and fillType.hudOverlayFilename ~= nil and fillType.hudOverlayFilename ~= '' then
            imageElement:setImageFilename(fillType.hudOverlayFilename)
        end
    end

    for i, tableRow in ipairs(self.tableRows) do
        local dataRow = self.dataView[i]

        if dataRow ~= nil then
            setImage(tableRow, dataRow)
        end
    end
end

Gui.CONFIGURATION_CLASS_MAPPING['distributor_outputsTableElement'] = OutputsTableElement
