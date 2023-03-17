local modFolder = g_currentModDirectory

---@class SelectInputDialog : MessageDialog
---@field outputsTable OutputsTableElement
---@field inputsTable InputsTableElement
---@field boxLayout ScrollingLayoutElement
---@field logo BitmapElement
---@field tableHeader BitmapElement
---@field tableFooter BitmapElement
---@field initialInputIndex number
---@field selectedInputIndex number
---@field needsInputsTableUpdate boolean
---
---@field processor Processor
---@field inputDataBindings table<string, string>
---@field outputDataBindings table<string, string>
---
---@field callbackFunction fun(target: any, inputIndex: number | nil, args: any)
---@field callbackTarget any
---@field callbackArgs any
SelectInputDialog = {}

local SelectInputDialog_mt = Class(SelectInputDialog, MessageDialog)

SelectInputDialog.CONTROLS = {
    'backButton',
    'okButton',
    'boxLayout',
    'inputsTable',
    'outputsTable',
    'tableHeader',
    'tableFooter',
    'logo',
}

function SelectInputDialog.new(target, mt)
    ---@type SelectInputDialog
    local self = MessageDialog.new(target, mt or SelectInputDialog_mt)

    self:registerControls(SelectInputDialog.CONTROLS)

    self.needsInputsTableUpdate = true
    self.selectedInputIndex = 0
    self.initialInputIndex = 0

    self.inputDataBindings = {}
    self.outputDataBindings = {}

    return self
end

function SelectInputDialog:load()
    g_gui:loadProfiles(modFolder .. 'xml/gui/guiProfiles.xml')
    g_gui:loadGui(modFolder .. 'xml/gui/dialogs/SelectInputDialog.xml', 'distributor_SelectInputDialog', self)
end

function SelectInputDialog:onGuiSetupFinished()
    MessageDialog.onGuiSetupFinished(self)

    ---@diagnostic disable-next-line: duplicate-set-field
    self.tableHeader.setVisible = function()
        -- void
    end

    self.logo:setImageFilename(modFolder .. 'textures/hud_icon.dds')
end

---@return ProcessInput | nil
function SelectInputDialog:getSelectedInput()
    if self.selectedInputIndex == 0 or self.processor == nil then
        return
    end

    return self.processor.inputs[self.selectedInputIndex]
end

function SelectInputDialog:onOpen()
    MessageDialog.onOpen(self)

    FocusManager:lockFocusInput(FocusManager.TOP, 150)
    FocusManager:lockFocusInput(FocusManager.BOTTOM, 150)

    self.boxLayout:invalidateLayout()

    if self.needsInputsTableUpdate then
        self.needsInputsTableUpdate = false
        self:updateInputsTable()
    end

    if FocusManager:getFocusedElement() == nil then
        self:setSoundSuppressed(true)
        FocusManager:setFocus(self.boxLayout)
        self:setSoundSuppressed(false)
    end
end

function SelectInputDialog:updateInputsTable()
    self.inputsTable:initialize(self.inputDataBindings)
    self.inputsTable.target = self
    self.inputsTable:updateData(self.processor)

    self:updateOutputsTable()
end

function SelectInputDialog:updateOutputsTable()
    self.outputsTable:initialize(self.outputDataBindings)
    self.outputsTable.target = self
    self.outputsTable:updateData(self:getSelectedInput())
end

---@param element ButtonElement
function SelectInputDialog:onCreateInputCellElement(element)
    local name = element.name

    if name ~= nil and self.inputDataBindings[name] == nil then
        self.inputDataBindings[name] = name
    end
end

---@param element ButtonElement
function SelectInputDialog:onCreateOutputCellElement(element)
    local name = element.name

    if name ~= nil and self.outputDataBindings[name] == nil then
        self.outputDataBindings[name] = name
    end
end

function SelectInputDialog:onInputSelectionChanged(index)
    self.selectedInputIndex = index

    if self.outputsTable ~= nil then
        self:updateOutputsTable()

        self:playSample(GuiSoundPlayer.SOUND_SAMPLES.HOVER)
    end
end

function SelectInputDialog:setCallback(func, target, args)
    self.callbackFunction = func
    self.callbackTarget = target
    self.callbackArgs = args
end

---@param processor Processor
---@param callback any
---@param target any
---@param args any
function SelectInputDialog:show(processor, callback, target, args)
    if processor == nil then
        return
    end

    if self.processor ~= processor then
        self.processor = processor
        self.needsInputsTableUpdate = true
    end

    g_gui:showDialog('distributor_SelectInputDialog')
    self:setCallback(callback, target, args)

    local currentInput = processor:getCurrentInput()

    if currentInput ~= nil then
        self.initialInputIndex = currentInput.index
    else
        self.initialInputIndex = 0
    end

    self:setSoundSuppressed(true)
    self.inputsTable:setSelectedIndex(self.initialInputIndex)
    self:setSoundSuppressed(false)
end

---@param index number | nil
function SelectInputDialog:sendCallback(index)
    self:close()

    if self.callbackFunction ~= nil then
        if self.callbackTarget ~= nil then
            self.callbackFunction(self.callbackTarget, index, self.callbackArgs)
        else
            self.callbackFunction(index, self.callbackArgs)
        end
    end

    self.processor = nil
end

function SelectInputDialog:onClickOk()
    if self.selectedInputIndex ~= 0 then
        self:sendCallback(self.selectedInputIndex)
        return false
    end

    return true
end

---@diagnostic disable-next-line: lowercase-global
g_selectInputDialog = SelectInputDialog.new()
g_selectInputDialog:load()
