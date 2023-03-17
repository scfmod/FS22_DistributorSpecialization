--[[
    Type hinting for sumneko lua-language-server
]]
---@class FillUnitObject
---@field supportedFillTypes table<number, boolean>
---@field fillType number
---@field fillLevel number

---@class FillTypeObject
---@field name string
---@field index number
---@field title string
---@field unitShort string?
---@field massPerLiter number
---@field hudOverlayFilename string?

---@type InputBinding
g_inputBinding = {}

---@type I18N
g_i18n = {}

---@type DensityMapHeightManager
g_densityMapHeightManager = {}

---@class SavegameObject
---@field xmlFile XMLFile
---@field key string
---@field resetVehicles boolean


---@class TableElementRow
---@field dataRowIndex number
---@field rowElement GuiElement
---@field columnElements table<string, table>

---@class TableElementDataRow<Data>: { itemData: Data, id: number, columnNames: table<string, TableElementDataCell>, columnCells: table<string, table> }

---@class TableElementDataCell
---@field text string
---@field overrideProfileName string
---@field profileName string
---@field isVisible boolean

printError = print
printWarning = print
