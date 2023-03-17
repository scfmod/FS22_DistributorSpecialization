local modFolder = g_currentModDirectory

---@class XMLSchemaExporterElement
---@field tag string
---@field children XMLSchemaExporterElement[]
---@field allowSubElements boolean
---@field hasMultipleElements boolean

---@class XMLSchemaExporter
---@field schema XMLSchema
---@field lines string[]
---@field lastLine number
XMLSchemaExporter = {}

local XMLSchemaExporter_mt = Class(XMLSchemaExporter)

---@param schema XMLSchema
---@return XMLSchemaExporter
function XMLSchemaExporter.new(schema)
    ---@type XMLSchemaExporter
    local self = setmetatable({}, XMLSchemaExporter_mt)

    self.schema = schema
    self.lines = {}
    self.lastLine = 0

    return self
end

---@private
---@param data XMLSchemaPathData
---@param root XMLSchemaExporterElement
function XMLSchemaExporter:iterateSchemaPath(data, root)
    local path = data.path
    local parent = root.children

    ---@type string[]
    local pathParts = path:split('.')
    local allowSubElements = true

    if pathParts[#pathParts]:find('#') ~= nil then
        local parts = pathParts[#pathParts]:split('#')

        if #parts == 2 then
            pathParts[#pathParts] = parts[1]
            table.insert(pathParts, parts[2])
        end

        allowSubElements = false
    end

    for i, _ in ipairs(pathParts) do
        local oldTag = pathParts[i]
        local tag = oldTag:gsub('%(%?%)', '')
        local partAllowSubElements = allowSubElements or i < #pathParts
        local hasMultipleElements = false

        if oldTag ~= tag then
            hasMultipleElements = true
        end

        local isAdded = false
        local addedElement = nil

        for _, child in ipairs(parent) do
            if child.tag == tag and child.allowSubElements then
                addedElement = child
                isAdded = true
                break
            end
        end

        if not isAdded then
            ---@type XMLSchemaExporterElement
            addedElement = {
                tag = tag,
                children = {},
                allowSubElements = partAllowSubElements,
                hasMultipleElements = hasMultipleElements
            }

            table.insert(parent, addedElement)
        end

        if i == #pathParts then
            addedElement.data = data
        end

        parent = addedElement.children
    end
end

---@param str string
---@param i number | nil
---@param indent string | nil
---@param lineBreak boolean | nil
---@return number
function XMLSchemaExporter:add(str, i, indent, lineBreak)
    local prefix = ''
    local suffix = ''
    local indentSize = (indent or prefix):len()

    if indentSize > 0 then
        prefix = string.format("<span style=\"margin-left:%dem\">", indentSize * 2)
        suffix = "</span>"
    end

    if lineBreak == true then
        suffix = suffix .. '<br>'
    end

    local value = prefix .. str .. suffix

    if i then
        table.insert(self.lines, value)
        self.lastLine = i
    else
        table.insert(self.lines, value)
        self.lastLine = #self.lines
    end

    return self.lastLine
end

---@param tbl string[]
function XMLSchemaExporter:addLines(tbl)
    for _, value in ipairs(tbl) do
        self:add(value)
    end
end

function XMLSchemaExporter:addHeader(title)
    self:addLines({
        '<!DOCTYPE html>',
        '<head>',
        ('  <title>XML Doc: %s</title>'):format(title),
        '  <link rel="stylesheet" href="styles.css">',
        '</head>',
    })
end

---@param title string
---@param basePath string
---@param rootBasePath string
function XMLSchemaExporter:generateHTML(title, basePath, rootBasePath)
    g_debugger:info('XMLSchemaExporter:generateHTML()')

    local orderedPaths = self.schema.orderedPaths

    ---@type XMLSchemaExporterElement
    local root = {
        children = {}
    }

    for _, data in ipairs(orderedPaths) do
        if data.path:startsWith(basePath) or data.path == rootBasePath then
            self:iterateSchemaPath(data, root)
        end
    end

    self:addHeader(title)

    local TAB = '  '
    local OPEN = "&lt;"
    local OPEN_END = "&lt;/"
    local CLOSE = "&gt;"
    local CLOSE_END = "/&gt;"
    local TYPE_TAG = 1
    local TYPE_ATTRIBUTE = 2
    local TYPE_ATTRIBUTE_VALUE = 3
    local TYPE_VALUE = 4

    local function format(str, type)
        if type == TYPE_TAG then
            str = string.format("<span id=\"tag\">%s</span>", str)
        elseif type == TYPE_ATTRIBUTE then
            str = string.format("<span id=\"attribute\">%s</span>", str)
        elseif type == TYPE_ATTRIBUTE_VALUE then
            str = string.format("<span id=\"attribute_value\">%s</span>", str)
        elseif type == TYPE_VALUE then
            str = string.format("<span id=\"value\">%s</span>", str)
        end

        return str
    end

    local function getAttributeInfo(data)
        local valueType = XMLValueType.TYPES[data.valueTypeId]
        local desc = string.format("Description: %s<br>", data.description or "missing")
        local type = string.format("Type: %s<br>", valueType.description)
        local default = ""

        if data.defaultValue ~= nil then
            default = string.format("Default: %s<br>", data.defaultValue)
        end

        local required = string.format("Required: %s<br>", data.isRequired and "yes" or "no")

        return desc .. type .. default .. required
    end

    local function buildAttribute(data, attributeType, spacing, useAllTypes, isDirect)
        if data.data ~= nil and (data.data.path:find("#") ~= nil or useAllTypes) then
            local valueType = XMLValueType.TYPES[data.data.valueTypeId]
            local valueStr = valueType.defaultStr

            if data.data.defaultValue ~= nil and type(data.data.defaultValue) == valueType.luaType then
                if valueType.luaPattern ~= nil then
                    if type(valueType.luaPattern) == "string" then
                        if string.match(data.data.defaultValue, valueType.luaPattern) == data.data.defaultValue then
                            valueStr = data.data.defaultValue
                        end
                    elseif type(valueType.luaPattern) == "table" then
                        for i = 1, #valueType.luaPattern do
                            if data.data.defaultValue == valueType.luaPattern[i] then
                                valueStr = data.data.defaultValue
                            end
                        end
                    end
                else
                    valueStr = data.data.defaultValue
                end
            end

            local attributeRaw = nil

            if isDirect then
                attributeRaw = format(valueStr, attributeType or TYPE_VALUE)
            else
                attributeRaw = string.format("%s=\"%s\"", format(data.tag, TYPE_ATTRIBUTE), format(valueStr, attributeType or TYPE_VALUE))
            end

            local attributeInfo = getAttributeInfo(data.data)
            -- local attribute = string.format("<div class=\"attribute\">%s<span class=\"attributeInfo\">%s</span></div>", attributeRaw, attributeInfo)
            local requiredClass = data.isRequired and ' required' or ''
            local specClass = data.data.path:startsWith('vehicle.distributor.processor.nodes.node(?).') and '' or ' spec'
            local attribute = string.format('<div class="attribute%s%s">%s<span class="attributeInfo">%s</span></div>', requiredClass, specClass, attributeRaw, attributeInfo)

            return (spacing or " ") .. attribute
        end

        return ""
    end

    local function addElement(line, indent, name, data, isRoot)
        if indent:len() == 1 then
            line = self:add("", line, indent, true) + 1
        end

        local hasOnlyAttributeChildren = true

        for _, subData in ipairs(data.children) do
            if subData.data == nil then
                hasOnlyAttributeChildren = false

                break
            elseif subData.data.path:find("#") == nil then
                hasOnlyAttributeChildren = false

                break
            end
        end

        local attributes = ""

        for _, subData in ipairs(data.children) do
            attributes = attributes .. buildAttribute(subData)
        end

        if hasOnlyAttributeChildren then
            line = self:add(string.format("%s%s%s", format(OPEN .. name, TYPE_TAG), format(attributes, TYPE_ATTRIBUTE), format(CLOSE_END, TYPE_TAG)), line, indent, true) + 1
        else
            line = self:add(string.format("%s%s%s", format(OPEN .. name, TYPE_TAG), format(attributes, TYPE_ATTRIBUTE), format(CLOSE, TYPE_TAG)), line, indent, true) + 1
        end

        for _, subData in ipairs(data.children) do
            if subData.data == nil then
                line = addElement(line, indent .. TAB, subData.tag, subData)
            elseif subData.data.path:find("#") == nil then
                if (indent .. TAB):len() == 1 then
                    line = self:add("", line, indent, true) + 1
                end

                local subAttributes = ""

                for _, subSubData in ipairs(subData.children) do
                    subAttributes = subAttributes .. buildAttribute(subSubData)
                end

                local attribute = buildAttribute(subData, TYPE_ATTRIBUTE_VALUE, "", true, true)
                line = self:add(string.format("%s%s%s%s%s%s", format(OPEN .. subData.tag, TYPE_TAG), subAttributes, format(CLOSE, TYPE_TAG), attribute, format(OPEN_END .. subData.tag, TYPE_TAG), format(CLOSE, TYPE_TAG)), line, indent .. TAB, true) + 1
            end
        end

        if not hasOnlyAttributeChildren then
            line = self:add(format(OPEN_END .. name .. CLOSE, TYPE_TAG), line, indent, true) + 1
        end

        return line
    end

    local currentLine = self.lastLine

    for _, element in ipairs(root.children) do
        currentLine = addElement(currentLine, '', element.tag, element, true)
    end

    -- local outputPath = modFolder .. 'docs/spec.html'
    local outputPath = 'C:/tmp/spec.html'
    local file = io.open(outputPath, 'w')

    assert(file ~= nil, string.format('Unable to write to file: %s', outputPath))

    for _, value in ipairs(self.lines) do
        file:write(value .. '\n')
    end

    file:close()
end

local hasExported = false

SpecializationManager.initSpecializations = Utils.appendedFunction(
    SpecializationManager.initSpecializations,
    function()
        if hasExported then
            return
        end

        local exporter = XMLSchemaExporter.new(Vehicle.xmlSchema)
        exporter:generateHTML('FS22_DistributorSpecialization', 'vehicle.distributor', 'vehicle')

        hasExported = true
    end
)
