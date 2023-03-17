---@class InputsTableElement : TableElement
---@field target any
---@field tableRows TableElementRow[]
---@field dataView TableElementDataRow<FillTypeObject>[]
---@field data TableElementDataRow<FillTypeObject>[]
---@field dataBindings table<string, string>
InputsTableElement = {}

local InputsTableElement_mt = Class(InputsTableElement, TableElement)

function InputsTableElement.new(target, mt)
    ---@type InputsTableElement
    local self = TableElement.new(target, mt or InputsTableElement_mt)

    self.dataBindings = {}

    return self
end

function InputsTableElement:initialize(dataBindings)
    TableElement.initialize(self)
    self.dataBindings = dataBindings
end

---@param processor Processor
function InputsTableElement:updateData(processor)
    self:clearData()

    for _, input in ipairs(processor.inputs) do
        local dataRow = self:buildDataRow(input)
        self:addRow(dataRow)
    end

    self:updateView()
end

---@param input ProcessInput
---@return TableElementDataRow<FillTypeObject>
function InputsTableElement:buildDataRow(input)
    ---@type TableElementDataRow<FillTypeObject>
    local row = TableElement.DataRow.new(input.index, self.dataBindings)

    -- local imageCell = row.columnCells[self.dataBindings['image']]
    local textCell = row.columnCells[self.dataBindings['text']]
    local fillType = input:getFillType()


    row.itemData = fillType
    textCell.text = fillType.title

    return row
end

---@param tableRow TableElementRow
---@return BitmapElement | nil
function InputsTableElement:getImageElement(tableRow)
    if tableRow.rowElement.elements[1] then
        ---@diagnostic disable-next-line: return-type-mismatch
        return tableRow.rowElement.elements[1].elements[1]
    end
end

function InputsTableElement:updateRows()
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
        local dataIndex = self.firstVisibleItem + i - 1
        local dataRow = self.dataView[dataIndex]

        if dataRow ~= nil and dataIndex <= math.min(#self.dataView, self.numActiveRows) then
            setImage(tableRow, dataRow)
        end
    end
end

function InputsTableElement:updateRowSelection()
    TableElement.updateRowSelection(self)
    self:updateScrollPosition()
end

function InputsTableElement:updateScrollPosition()
    if not self.target then
        return
    end

    local headerElement = self.target.tableHeader
    local footerElement = self.target.tableFooter

    if headerElement then
        if self.firstVisibleItem > 1 then
            headerElement:setDisabled(false)
        else
            headerElement:setDisabled(true)
        end
    end

    if footerElement then
        if self.firstVisibleItem + self.visibleItems > self.numActiveRows then
            footerElement:setDisabled(true)
        else
            footerElement:setDisabled(false)
        end
    end
end

Gui.CONFIGURATION_CLASS_MAPPING['distributor_inputsTableElement'] = InputsTableElement
