local C  = require('easy_dialog.constants')
local U  = require('easy_dialog.utils')
local Engine = require('easy_dialog.core.engine')(C, U)
local Dialog = require('easy_dialog.core.dialog')(C, U, Engine)

local easy_dialog = { _VERSION = C.VERSION }

easy_dialog.config = {
    PAGINATION_TEXT = 'Page. %d/%d',
    EMPTY_LIST_TEXT = '{CCCCCC}Empty list.',
    PAGINATION_PREV = '{BDBDBD}<< Prev page',
    PAGINATION_NEXT = '{BDBDBD}Next page >>',
}

Engine.set_config_provider(function() return easy_dialog.config end)

function easy_dialog.configure(user_config)
    if type(user_config) ~= 'table' then return end
    for k, v in pairs(user_config) do
        if easy_dialog.config[k] ~= nil then
            easy_dialog.config[k] = v
        end
    end
end

easy_dialog.LaunchMode = C.LaunchMode
easy_dialog.Dialog     = Dialog

function easy_dialog.init() Engine.init() end
function easy_dialog.stop() Engine.stop() end

function easy_dialog.register(name, dialog_obj) Engine.register(name, dialog_obj) end
function easy_dialog.start(name, data) Engine.start(name, data) end
function easy_dialog.go(name, data) Engine.go(name, data) end
function easy_dialog.done(result) Engine.done(result) end
function easy_dialog.show(dialog, is_temporary, reset_pagination) Engine.show(dialog, is_temporary, reset_pagination) end
function easy_dialog.back() Engine.back() end
function easy_dialog.home() Engine.home() end

function easy_dialog.alert(caption, text, onOK)
    local d = Dialog.new()
        :setCaption(caption)
        :setStyle('msgbox')
        :setContent(text)
        :setButtons('OK', '')
        :setOnResponse(function(_, button)
            if button == 1 then U.safe_call(onOK) end
        end)
    Engine.show(d, true)
end

function easy_dialog.confirm(caption, text, onConfirm)
    local d = Dialog.new()
        :setCaption(caption)
        :setStyle('msgbox')
        :setContent(text)
        :setButtons('OK', 'Îòìåíà')
        :setOnResponse(function(_, button)
            U.safe_call(onConfirm, button == 1)
        end)
    Engine.show(d, true)
end

function easy_dialog.prompt(caption, text, onInput)
    local d = Dialog.new()
        :setCaption(caption)
        :setStyle('input')
        :setContent(text)
        :setButtons('Ãîòîâî', 'Îòìåíà')
        :setOnResponse(function(_, button, _, input)
            if button == 1 then U.safe_call(onInput, input) end
        end)
    Engine.show(d, true)
end


return easy_dialog
