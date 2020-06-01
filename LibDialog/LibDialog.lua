--[========================================================================[
    This is free and unencumbered software released into the public domain.

    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.

    In jurisdictions that recognize copyright laws, the author or authors
    of this software dedicate any and all copyright interest in the
    software to the public domain. We make this dedication for the benefit
    of the public at large and to the detriment of our heirs and
    successors. We intend this dedication to be an overt act of
    relinquishment in perpetuity of all present and future rights to this
    software under copyright law.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
    OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
    ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.

    For more information, please refer to <http://unlicense.org/>
--]========================================================================]

local MAJOR, MINOR = "LibDialog", 1.25
if _G[MAJOR] ~= nil and (_G[MAJOR].version and _G[MAJOR].version >= MINOR) then return end

--TODO: Disable if not testing!
local LibraryTestMode = false

--Library table, name and version
local lib = {}
lib.name    = MAJOR
lib.version = MINOR

--Add global variable "LibDialog"
_G[MAJOR] = lib

------------------------------------------------------------------------
-- 	Local variables, global for the library
------------------------------------------------------------------------
local existingDialogs = {}
local dialogTextParams = {}
local dialogAdditionalOptions = {}

lib.lastShownDialogAddonName = nil
lib.lastShownDialogDialogName = nil
lib.lastShownDialogData = {}
lib.lastZO_Dialogs_ShowDialogReturnedDialog = {}

------------------------------------------------------------------------
-- 	Helper functions
------------------------------------------------------------------------
local function StringOrFunctionOrGetString(stringVar)
    if type(stringVar) == "function" then
        return stringVar()
    elseif type(stringVar) == "number" then
        return GetString(stringVar)
    end
    return stringVar
end

------------------------------------------------------------------------
-- 	Dialog creation functions
------------------------------------------------------------------------
--register the unique dialog name at the global ESO_Dialogs namespace
local function RegisterCustomDialogAtZOsDialogs(dialogName, dialogStandardData)
    if not dialogName or dialogName == "" or not dialogStandardData then return end

    local function standardButtonCallback(dialog) end
    local buttonCallbackYes = dialogStandardData.buttonCallbackYes or standardButtonCallback
    local buttonCallbackNo = dialogStandardData.buttonCallbackNo or standardButtonCallback
    local function standardSetupFunc(dialog, dialogData) end
    local setupFunc = dialogStandardData.setup or standardSetupFunc

    --Define a new custom ESO dialog now
    ESO_Dialogs[dialogName] = {
        canQueue = true,
        uniqueIdentifier = dialogName,
        title = dialogStandardData.title,
        mainText = dialogStandardData.mainText,
        buttons =  {
            [1] = {
                text = SI_DIALOG_CONFIRM,
                callback = buttonCallbackYes,
            },
            [2] = {
                text = SI_DIALOG_CANCEL,
                callback = buttonCallbackNo,
            }
        },
        setup = setupFunc,
    }

    --Add additional options to the dialog?
    --Options like "editBox = { ... } or "customControl = {...}"
    --You can find all options here in the lines ff
    --https://github.com/esoui/esoui/blob/0569f38e70254b4e08a5eab088c4ce5e7e46be55/esoui/libraries/zo_dialog/zo_dialog.lua#L568

    --Valid "special" additional dialog parameters
    local specialAdditionalOptions = {
        ["buttonData"]      = { paramTypes = {"table"} }, -- needs to be a table with key = buttonIndex (1 or 2). Subdata can be visible (boolean or function returning a boolean)
        -->Table with key = buttonIndex (1 or 2) and a table as value. This table can contain the following entries:
        --->text: number (read via GetString(number), function returning a string, or string
        --->callback: function
        --->visible: function returning boolean, or boolean
        --->keybind: function returning a keybind, or keybind (if nil DIALOG_PRIMARY will be used for buttonIndex1 and DIALOG_NEGATIVE for buttonIndex2)
        --->noReleaseOnClick: boolean
        --->enabled: function returning boolean, or boolean
        --->clickSound: SOUNDS.SOUND_NAME
        --->requiresTextInput: boolean
    }

    --Valid additional dialog parameters
    local validAdditionalOptions = {
        ["canQueue"]        = { paramTypes = {"boolean", "function"} },
        ["title"]           = { paramTypes = {"table", } },
        -- text: String or function returning a string (can contain placeholders <<1>> etc. for zo_strformat)
        -- align: TEXT_ALIGN_* member to set the alignment of the text (TEXT_ALIGN_LEFT, TEXT_ALIGN_RIGHT, or TEXT_ALIGN_CENTER....left is default).
        -- timer: index,  which indicates that a certain parameter should be treated as seconds in a timer, and converted to time format
        --      (so if title contains "timer = 2", the 2nd parameter (<<2>>) in title.text is converted via zo_strformat to time format before being placed
        --      in the string).
        --Can this dialog be queued and called later, or not?
        ["mainText"]        = { paramTypes = {"table", } },
        -- text: String or function returning a string (can contain placeholders <<1>> etc. for zo_strformat)
        -- align: TEXT_ALIGN_* member to set the alignment of the text (TEXT_ALIGN_LEFT, TEXT_ALIGN_RIGHT, or TEXT_ALIGN_CENTER....left is default).
        -- timer: index,  which indicates that a certain parameter should be treated as seconds in a timer, and converted to time format
        --      (so if mainText contains "timer = 2", the 2nd parameter (<<2>>) in mainText.text is converted via zo_strformat to time format before being placed
        --      in the string).
        --Can this dialog be queued and called later, or not?
        ["callback"]        = { paramTypes = {"function"}, },
        -- A callback function of the dialog, fired as the dialog is shown via ZO_Dialogs_ShowDialog
        -- 1 parameter in the callback function: number dialogID
        ["updateFn"]        = { paramTypes = {"function"}, },
        -- an update function called automatically as OnUpdate fires for the dialog
        ["gamepadInfo"]     = { paramTypes = {"table"} },
        --TODO: Contents?
        ["showLoadingIcon"] = { paramTypes = {"boolean"} },
        --An option to show an animated loading icon near the main text. See parameter "loadingIcon" below
        ["customLoadingIcon"]     = { paramTypes = {"string", "function"} },
        --You can specify your own texture here which should be used as the loading icon.
        --dialog.loadingIcon = "string texture" (see https://github.com/esoui/esoui/blob/0569f38e70254b4e08a5eab088c4ce5e7e46be55/esoui/libraries/zo_dialog/zo_dialog.lua#L580)
        --As the "dialog" table will be created within function ZO_Dialogs_ShowDialog we need to apply our custom texture somehow to the control.
        --We will use the "callback" function of the dialog to achieve this! If a callback function was already defined we will "PreHook" this function to insert the texture first.
        ["modal"]           = { paramTypes = {"boolean"} },
        --Show the dialog modal or not
        ["warning"]         = { paramTypes = {"table"} },
        --Show a warning text at teh dialog.
        -- table with parameters
        --->string or function text,
        --->number timer,
        -----> You specify the timer index number here.
        -----> And inside the table "textParams" (see below) the warningParams the key must be the timer index, and the value the milliseconds left of that timer.
        -----> The attribute above (warning.text) should contain placeholders like <<1>> and <<2>> for a zo_strformat with the timer numbers! It will show a countdown then.
        --->boolean verboseTimer,
        ----> Show more details at the cooldown
        ["editBox"]         = { paramTypes = {"table"} },
        --Table specifiying an input edit control at the dialog. The following parameters can be added to the table:
        --->textType: a textType constant (nil will be using TEXT_TYPE_ALL)
        ---->  TEXT_TYPE_ALL = 0
        ---->  TEXT_TYPE_PASSWORD = 1
        ---->  TEXT_TYPE_NUMERIC = 2
        ---->  TEXT_TYPE_NUMERIC_UNSIGNED_INT = 3
        ---->  TEXT_TYPE_ALPHABETIC = 4
        ---->  TEXT_TYPE_ALPHABETIC_NO_FULLWIDTH_LATIN = 5
        --->specialCharacters: a table with characters which can be entered into the input field. Table key is a number, value a character
        --->maxInputCharacters: number of maximum possible entered characters
        --->defaultText: number (will be used with function GetString(number)), or string. The default text shown at the edit box. Will be replaced upon typing in it
        --->autoComplete: Table, containing info for a ZO_AutoComplete control attached to the editBox (will be created new if not existing).
        ---->subtable includeFlags: table with the include flags of the ZO_AutoComplete, e.g. { AUTO_COMPLETE_FLAG_GUILD, AUTO_COMPLETE_FLAG_RECENT, AUTO_COMPLETE_FLAG_RECENT_TARGET, AUTO_COMPLETE_FLAG_RECENT_CHAT },
        ---->subtable excludeFlags: table with the exclude flags of the ZO_AutoComplete, e.g.  {AUTO_COMPLETE_FLAG_FRIEND },
        ---->boolean onlineOnly: boolean parameter online only, e.g. AUTO_COMPLETION_ONLINE_OR_OFFLINE
        ---->number maxResults: number parameter max results, e.g. MAX_AUTO_COMPLETION_RESULTS
        --->validatesText: boolean should the text in the editbox be validated
        --->validator: function for the text validation
        --->matchingString: string, Should the input into the editbox should be compared to this mathcing string (e.g. used for DESTROY confirm dialog)
        ["radioButtons"]  = { paramTypes = {"table"} },
        -->Table specifiying radio buttons at the dialog. The table needs the radioButtonIndex as key and a subTable as value for each radio button.
        -->The following parameters can be added to the subTable of each radioButton:
        --->text: String
        --->data: Table with data of the radioButton
        ["customControl"]   = { paramTypes = {"userdata", "function"} },
        --An own created control you would like to anchor and show in the dialog
    }

    --Check if additional options were specified
    local additionalOptions = dialogAdditionalOptions[dialogName]
    if additionalOptions ~= nil then
        local callBackRegisteredData
        local customLoadingIconData
        local showLoadingIcon = false
        --d(">Add. options will be added")
        for additionalOptionTag, additionalOptionData in pairs(additionalOptions) do
            --d(">>checking additionalOptionTag: " ..tostring(additionalOptionTag))
            local validAdditionalOptionsOption = validAdditionalOptions[additionalOptionTag]
            local specialValidAdditionalOptionsOption = specialAdditionalOptions[additionalOptionTag]
            local typeOfParam = type(additionalOptionData)

            --Normal additions like defined in /esoui/libraries/zo_dialog.lua
            if validAdditionalOptionsOption ~= nil and validAdditionalOptionsOption.paramTypes ~= nil then
                --d(">>>checking valid params of this additional option")
                for _, validParamType in ipairs(validAdditionalOptionsOption.paramTypes) do
                    if validParamType == typeOfParam then
                        --d(">>>>adding this additional option")
                        ESO_Dialogs[dialogName][additionalOptionTag] = additionalOptionData
                        --Checks for special added tags
                        if additionalOptionTag == "showLoadingIcon" then
                            showLoadingIcon = true
                        elseif additionalOptionTag == "callback" then
                            callBackRegisteredData = additionalOptionData
                        elseif additionalOptionTag == "customLoadingIcon" then
                            customLoadingIconData = additionalOptionData
                        end
                    end
                end
            end

            --Was a custom loading icon registered?
            if showLoadingIcon == true and customLoadingIconData ~= nil then
                local function updateCustomLoadingIconTexture()
                    local textCtrl = GetControl(ZO_Dialog1, "Loading")
                    local loadingIconCtrl = GetControl(ZO_Dialog1, "LoadingIcon")
                    if loadingIconCtrl ~= nil and loadingIconCtrl.SetTexture then
                        local texturePath
                        if type(customLoadingIconData) == "function" then
                            texturePath = customLoadingIconData()
                        else
                            texturePath = customLoadingIconData
                        end
                        loadingIconCtrl:SetTexture(texturePath)
                        --ZO_Dialogs_SetDialogLoadingIcon(loadingIconCtrl, textCtrl, showLoadingIcon)
                    end
                end
                --Was a callback also registered already?
                if callBackRegisteredData ~= nil then
                    --Create a new function, calling our code for the custom loading icon first,
                    --and then the exisitng callback
                    local allreadyRegisteredCallback = ESO_Dialogs[dialogName]["callback"]
                    local function dialogCallBackNew()
                        updateCustomLoadingIconTexture()
                        allreadyRegisteredCallback()
                    end
                    ESO_Dialogs[dialogName]["callback"] = function() dialogCallBackNew() end
                else
                    --No callback registeerd yet, so use this for the csutom loading icon
                    --Create a callback function to regisetr the custom loading icon
                    ESO_Dialogs[dialogName]["callback"] = function() updateCustomLoadingIconTexture() end
                end
            end

            --Special dialog stuff like visible function/value of buttons etc.
            if specialValidAdditionalOptionsOption ~= nil and specialValidAdditionalOptionsOption.paramTypes ~= nil then
                --d(">Special add. options will be added")
                for _, validSpecialParamType in ipairs(specialValidAdditionalOptionsOption.paramTypes) do
                    --d(">>checking validSpecialParamType: " ..tostring(validSpecialParamType))
                    if validSpecialParamType == typeOfParam then
                        --Buttons
                        if additionalOptionTag == "buttonData" then
                            --d(">>>buttonData found")
                            for buttonIndex, actualButtonData in pairs(ESO_Dialogs[dialogName].buttons) do
                                --d(">>>>checking button #: " ..tostring(buttonIndex))
                                local newButtonData = additionalOptionData[buttonIndex]
                                if newButtonData ~= nil then
                                    --d(">>>>>new button data found!")
                                    for newButtonDataKey, newButtonDataValue in pairs(newButtonData) do
                                        --d(">>>>>>apply new button data: " ..tostring(newButtonDataKey))
                                        ESO_Dialogs[dialogName].buttons[buttonIndex][newButtonDataKey] = newButtonDataValue
                                    end
                                end
                            end
                        end
                    end
                end
            end

        end -- for additionalOptionTag, additionalOptionData in pairs(additionalOptions) do
    end

    --Valid text parameters
    local validTextParams = {
        ["titleParams"]             = { paramTypes = {"table"} },
        --table containing key = number 1 to n and value = string or function returning a string.
        --Used to change the placeholders <<1>>, <<2>> etc. in the dialog's title.text string
        ["mainTextParams"]          = { paramTypes = {"table"} },
        --table containing key = number 1 to n and value = string text or function returning string.
        --Used to change the placeholders <<1>>, <<2>> etc. in the dialog's mainText.text string
        --Example:
        -- If the main text in the dialog has 2 parameters (e.g "Hello <<1>> <<2>>"), then the 3rd parameter of ZO_Dialogs_ShowDialog should contain a subtable called
        -- "mainTextParams" which itself contains 2 members, the first will go into the <<1>> and the second will go into the <<2>>. The 3rd parameter
        -- in ZO_Dialogs_ShowDialog can also contain a titleParams subtable which is used to fill in the parameters in the title, if needed.
        --
        -- So as an example, let's say you had defined a dialog in InGameDialogs called "TEST_DIALOG" with
        --      title = { text = "Dialog <<1>>" } and mainText = { text = "Main <<1>> Text <<2>>" }
        -- And you called
        --      ZO_Dialogs_ShowDialog("TEST_DIALOG", {5}, {titleParams={"Test1"}, mainTextParams={"Test2", "Test3"}})
        -- The resulting dialog would have a title that read "Dialog Test1" and a main text field that read "Main Test2 Text Test3".
        -- The 5 passed in the second parameter could be used by the callback functions to perform various tasks based on this value.
        ["warningParams"]           = { paramTypes = {"table"} },
        --table with parameters: Like the mainTextparams table is acting for maintext, this table is acrting for the warning table.
        --{ number timer }
        --The table here needs as key the parameter which should be replaced in the warning.text field placeholder <<[table key]>>
        ["buttonTextOverrides"]     = { paramTypes = {"table"} },
        --needs to be a table with key = buttonIndex (1 or 2) and will then overwrite the text of the buttons
        ["initialEditText"]         = { paramTypes = {"string"} },
        --used for additionalOptions.editBox as initial edit box text shown
    }
    --Should custom text parameters be used?
    local textParams = dialogTextParams[dialogName]
    if textParams ~= nil then
        --Validate the text parameters
        for textParamsTag, textParamsData in pairs(textParams) do
            local validTextParamsOption = validTextParams[textParamsTag]
            local typeOfParam = type(textParamsData)

            --Check the parameter type
            if validTextParamsOption ~= nil and validTextParamsOption.paramTypes ~= nil then
                for _, validParamType in ipairs(validTextParamsOption.paramTypes) do
                    if validParamType ~= typeOfParam then
                        dialogTextParams[dialogName][textParamsTag] = nil
                    end
                end
            end
        end
    end

    --return the created ESO custom dialog
    return ESO_Dialogs[dialogName]
end

--Create the new dialog now
local function createCustomDialog(uniqueAddonName, uniqueDialogName, title, body, callbackYes, callbackNo, callbackSetup)
    local dialogName = uniqueAddonName .. "_" .. uniqueDialogName
    local dialogStandardData = {
        setup               = callbackSetup,
        title               = { text = title },
        mainText            = { text = body },
        buttonCallbackYes   = callbackYes,
        buttonCallbackNo    = callbackNo,
    }
    --Register the unique dialog name at the global ESO_Dialogs namespace now, and add 2 buttons (confirm, reject)
    local dialog = RegisterCustomDialogAtZOsDialogs(dialogName, dialogStandardData)
    dialog.createdForAddon = uniqueAddonName
    dialog.addonsDialogName = uniqueDialogName
    return dialog
end

--Show the dialog now
local function showDialogNow(uniqueDialogName, data)
    --Were textParams provided?
    local textParams = dialogTextParams[uniqueDialogName]
    --Show the dialog now, and provide it the data
    local dialog = ZO_Dialogs_ShowDialog(uniqueDialogName, data, textParams)
    --Saved the last shown dialog (return value "dialog" of function ZO_Dialogs_ShowDialog in the table of the lib
    if dialog ~= nil then
        lib.lastZO_Dialogs_ShowDialogReturnedDialog[uniqueDialogName] = dialog
    end
end


------------------------------------------------------------------------
-- 	Library functions
------------------------------------------------------------------------
function lib:RegisterDialog(uniqueAddonName, uniqueDialogName, title, body, callbackYes, callbackNo, callbackSetup, forceUpdate, additionalOptions, textParams)
    --Is any of the needed variables not given?
    local titleStr = StringOrFunctionOrGetString(title)
    local bodyStr = StringOrFunctionOrGetString(body)
    assert (titleStr ~= nil, string.format("[" .. MAJOR .. "]Error: Missing title for dialog with the unique identifier \'%s\', addon \'%s\'!", tostring(uniqueDialogName), tostring(uniqueAddonName)))
    assert (bodyStr ~= nil, string.format("[" .. MAJOR .. "]Error: Missing body text for dialog with the unique identifier \'%s\', addon \'%s\'!", tostring(uniqueDialogName), tostring(uniqueAddonName)))
    forceUpdate = forceUpdate or false
    if callbackYes == nil then
        callbackYes = function() end
    end
    if callbackNo == nil then
        callbackNo = function() end
    end
    if callbackSetup == nil then
        callbackSetup = function(dialog, data) end
    end
    --Is there already a dialog for this addon and does the uniqueDialogName already exist?
    if existingDialogs[uniqueAddonName] == nil then
        existingDialogs[uniqueAddonName] = {}
    end
    local dialogs = existingDialogs[uniqueAddonName]
    if not forceUpdate then
        assert(dialogs[uniqueDialogName] == nil, string.format("[" .. MAJOR .. "]Error: Dialog with the unique identifier \'%s\' is already registered for the addon \'%s\'!", tostring(uniqueDialogName), tostring(uniqueAddonName)))
    end
    --Create the table for the dialog in the addon
    dialogs[uniqueDialogName] = {}
    local dialog = dialogs[uniqueDialogName]
    if not dialog then return end
    local dialogName = uniqueAddonName .. "_" .. uniqueDialogName
    --Were additionalOptions specified as well?
    if additionalOptions ~= nil and type(additionalOptions) == "table" then
        --Cached them in the library so they can be fetched as ZO_Dialogs_ShowDialog is used via LibDialog:ShowDialog
        dialogAdditionalOptions[dialogName] = additionalOptions
    end
    --Were textParams specified as well?
    if textParams ~= nil and type(textParams) == "table" then
        --Cached them in the library so they can be fetched as ZO_Dialogs_ShowDialog is used via LibDialog:ShowDialog
        dialogTextParams[dialogName] = textParams
    end
    --Create the dialog now
    dialog.dialog = createCustomDialog(uniqueAddonName, uniqueDialogName, titleStr, bodyStr, callbackYes, callbackNo, callbackSetup)
    --return the new created dialog now
    return dialog.dialog
    end

    --Show a registered dialog now
    function lib:ShowDialog(uniqueAddonName, uniqueDialogName, data)
    --Show the dialog now
    local dialogName = uniqueAddonName .. "_" .. uniqueDialogName
    assert(ESO_Dialogs[dialogName] ~= nil, string.format("[" .. MAJOR .. "]Error: Dialog with the unique identifier \'%s\' does not exist in ESO_Dialogs, addon \'%s\'!", tostring(uniqueDialogName), tostring(uniqueAddonName)))
    --Is there already a dialog for this addon and does the uniqueDialogName already exist?
    local dialogs = existingDialogs[uniqueAddonName]
    assert(dialogs ~= nil and dialogs[uniqueDialogName] ~= nil, string.format("[" .. MAJOR .. "]Error: Dialog with the unique identifier \'%s\' does not exist for the addon \'%s\'!", tostring(uniqueDialogName), tostring(uniqueAddonName)))
    --Show the dialog now
    lib.lastShownDialogAddonName = uniqueAddonName
    lib.lastShownDialogDialogName = uniqueDialogName
    lib.lastShownDialogData = data
    showDialogNow(dialogName, data)
    return true
    end

--======================================================================================================================
--v-- TEST FUNCTION - BEGIN - Enable via setting variable "LibraryTestMode"=true at the top of this file!          --v--
--======================================================================================================================
    --Create a new dialog and show it 3 seconds after EVENT_ADD_ON_LOADED
    local function loadTest()
        --Is the testing enabled?
        if not LibraryTestMode then return end

        --Security check for displayname/account name @Baertram. If you want to test as well comment this line below!
        if GetDisplayName() ~= "@Baertram" then return end

        --See file LibDialog.lua for the descriptions of the tables additionalOptions and textParams
        --and in addition check this source code file of ZOs code here:
        --https://github.com/esoui/esoui/blob/0569f38e70254b4e08a5eab088c4ce5e7e46be55/esoui/libraries/zo_dialog/zo_dialog.lua#L351
        --function ZO_Dialogs_ShowDialog(name, data, textParams, isGamepad) and it's description above the function
        local additionalOptions = {
            canQueue = true,
            callback = function(dialogId) d("callback func was called for dialog: " ..tostring(dialogId)) end,
            --updateFn = function() d("updateFn func was called") end,
            showLoadingIcon = true,
            customLoadingIcon = "/esoui/art/icons/ability_u26_vampire_infection_stage0.dds",
            title = {
                text = "Title <<1>>",
                timer = 1,
            },
            mainText = {
                text = "Test Body <<1>> <<2>>",
                timer = 2,
            },
            warning = {
                text = function() return "WARNING - Time left: <<1>>" end,
                timer = 1,
                verboseTimer = true,
            },
            modal = false,
            editBox = {
                textType = TEXT_TYPE_ALL,
                specialCharacters = {"a", "b", "c", "d"},
                maxInputCharacters = 3,
                defaultText = "a",
            },

            -->Table with key = buttonIndex (1 or 2) and a table as value. This table can contain the following entries:
            --->text: number (read via GetString(number), function returning a string, or string
            --->callback: function
            --->visible: function returning boolean, or boolean
            --->keybind: function returning a keybind, or keybind (if nil DIALOG_PRIMARY will be used for buttonIndex1 and DIALOG_NEGATIVE for buttonIndex2)
            --->noReleaseOnClick: boolean
            --->enabled: function returning boolean, or boolean
            --->clickSound: SOUNDS.SOUND_NAME
            --->requiresTextInput: boolean
            buttonData      = {
                [1] = {
                    visible = function() return true end,
                },
                [2] = {
                    enabled = function() return true end,
                },
            },
            radioButtons = {
                [1] = {
                    text = "rb1",
                    data = {rb=1}
                },
                [2] = {
                    text = "rb2",
                    data = {rb=2}
                },
                [3] = {
                    text = "rb3",
                    data = {rb=3}
                },
            }
        }
        -- textParams:
        --  ["warningParams"]           = { paramTypes = {"table"} },   --table with parameters { number timer }
        --  ["buttonTextOverrides"]     = { paramTypes = {"table"} },   --needs to be a table with key number buttonIndex (1 or 2) and String value for the buttonText
        --  ["initialEditText"]         = { paramTypes = {"string"} },  --used for additionalOptions.editBox as initial edit box text shown
        --  ["titleParams"]             = { "Text here" or function },  --used to change the title
        --  ["mainTextParams"]          = { "Text here" or function },  --used to change the mainText
        local textParams = {
            ["warningParams"] = { [1] = 10000 }, --The table key 1 is the timer index set within table additionalOptions.warning.timer !
            ["titleParams"] = { [1] = 7000 }, --The table key 1 is the timer index set within table additionalOptions.warning.timer !
            ["mainTextParams"] = {
                [1] = "ahoi",
                [2] = 5000
            }, --The table key 1 is the timer index set within table additionalOptions.warning.timer !
            ["buttonTextOverrides"] = {
                [1] = "Test YES",
                [2] = "Test NO",
            },
            ["initialEditText"] = "AFK!",
        }


        --Create and call the new dialog 3 seconds after event_add_on_loaded e.g.
        zo_callLater(function()
            LibDialog:RegisterDialog("MyAddonTest", "MyAddonTest_Dialog1", "Title", "body", function() d("yes") end, function() d("no") end, nil, true, additionalOptions, textParams)
            LibDialog:ShowDialog("MyAddonTest", "MyAddonTest_Dialog1", nil)
        end, 3000)
    end
--======================================================================================================================
--^-- TEST FUNCTION - END                                                                                          --^--
--======================================================================================================================

    --Addon loaded function
    local function OnLibraryLoaded(event, name)
    --Only load lib if ingame
    if name:find("^ZO_") then return end
        EVENT_MANAGER:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
        --Provide the library the "list of registered dialogs"
        lib.dialogs = existingDialogs
        lib.dialogTextParams = dialogTextParams

        --TODO: Remove after testing
        loadTest()
    end

    --Load the addon now
    EVENT_MANAGER:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, OnLibraryLoaded)
