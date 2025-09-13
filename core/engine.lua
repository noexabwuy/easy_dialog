return function(C, U)
    local Engine = {}
    local active_dialogs = {}
    local nav_stack = {}
    local registry = {}
    local dialog_thread = nil
    local next_auto_id = C.MIN_DIALOG_ID
    local config_provider = nil

    function Engine.set_config_provider(fn) config_provider = fn end
    
    local function CFG() return (config_provider and config_provider()) or {
        PAGINATION_TEXT = 'Стр. %d/%d',
        EMPTY_LIST_TEXT = '{CCCCCC}Список пуст.',
        PAGINATION_PREV = '{BDBDBD}<< Назад',
        PAGINATION_NEXT = '{BDBDBD}Далее >>',
    } end

    local function rotate_next_id()
        next_auto_id = next_auto_id + 1
        if next_auto_id > C.MAX_DIALOG_ID then next_auto_id = C.MIN_DIALOG_ID end
    end

    function Engine.allocate_id()
        local start_id = next_auto_id
        repeat
            if not active_dialogs[next_auto_id] then
                local id = next_auto_id
                rotate_next_id()
                return id
            end
            rotate_next_id()
        until next_auto_id == start_id
        error('[easy-dialog] No available dialog IDs.')
    end

    function Engine.is_active(id) return id and active_dialogs[id] ~= nil end

    function Engine.get_active(id) return active_dialogs[id] end

    function Engine.mark_inactive(id) if id then active_dialogs[id] = nil end end

    local function is_registered(dialog_obj)
        for _, d in pairs(registry) do if d == dialog_obj then return true end end
        return false
    end

    local function clear_current_dialog_slot()
        local current_id = (sampGetCurrentDialogId and sampGetCurrentDialogId()) or 0
        if current_id > 0 and active_dialogs[current_id] then
            active_dialogs[current_id] = nil
        end
    end

    function Engine.show(dialog, is_temporary, reset_pagination)
        if type(dialog) ~= 'table' or type(dialog._prepare_for_show) ~= 'function' then
            U.errorln('invalid dialog object passed to Engine.show')
            return
        end
        if not dialog_thread or (dialog_thread and dialog_thread:status() == 'dead') then
            Engine.init()
        end
        if reset_pagination then dialog._currentPage = 1 end
        if not is_temporary then
            if #nav_stack == 0 or nav_stack[#nav_stack] ~= dialog then
                if dialog._isPaginated then dialog._currentPage = 1 end
                nav_stack[#nav_stack+1] = dialog
            end
        end
        local caption, text, style, btn1, btn2 = dialog:_prepare_for_show(CFG())
        sampShowDialog(dialog.id, caption, text, btn1, btn2, style)
        if sampIsDialogActive and sampIsDialogActive() then
            local cur = sampGetCurrentDialogId and sampGetCurrentDialogId() or 0
            if cur == dialog.id then
                active_dialogs[dialog.id] = dialog
            else
                active_dialogs[dialog.id] = nil
            end
        else
            active_dialogs[dialog.id] = nil
        end
    end

    function Engine.register(name, dialog_obj)
        if type(name) ~= 'string' or name == '' then
            U.errorln('name must be non-empty.')
            return
        end
        if type(dialog_obj) ~= 'table' or type(dialog_obj._prepare_for_show) ~= 'function' then
            U.errorln('requires a valid dialog object.')
            return
        end
        if registry[name] then
            U.warn("Dialog '%s' is already registered.", name)
        end
        registry[name] = dialog_obj
    end

    local function navigate_to(name, data, is_start)
        clear_current_dialog_slot()
        local dialog = registry[name]
        if not dialog then
            U.errorln('attempt to navigate to unregistered dialog: %s', tostring(name))
            return
        end
        if is_start or dialog.launch_mode == C.LaunchMode.ROOT then
            nav_stack = {}
        elseif dialog.launch_mode == C.LaunchMode.SINGLE_TOP then
            local found_at = nil
            for i = #nav_stack, 1, -1 do if nav_stack[i] == dialog then found_at = i; break end end
            if found_at then
                while #nav_stack > found_at do table.remove(nav_stack) end
                Engine.show(dialog, true)
                return
            end
        end
        dialog.startData = data
        U.safe_call(dialog.onStart, dialog, data)
        Engine.show(dialog, false)
    end

    function Engine.start(name, data) navigate_to(name, data, true) end

    function Engine.go(name, data)    navigate_to(name, data, false) end

    function Engine.done(result_data)
        if #nav_stack < 1 then return end
        clear_current_dialog_slot()
        table.remove(nav_stack)
        if #nav_stack > 0 then
            local parent = nav_stack[#nav_stack]
            if is_registered(parent) then
                U.safe_call(parent.onProcessResult, parent, result_data)
                Engine.show(parent, true)
            else
                U.warn("Parent dialog for 'done' is no longer registered. Cannot process result.")
            end
        else
            sampCloseCurrentDialogWithButton(0)
        end
    end

    function Engine.back()
        if #nav_stack > 1 then
            clear_current_dialog_slot()
            table.remove(nav_stack)
            while #nav_stack > 0 and not is_registered(nav_stack[#nav_stack]) do
                U.warn('Popping a dead dialog from nav_stack.')
                table.remove(nav_stack)
            end
            if #nav_stack > 0 then
                Engine.show(nav_stack[#nav_stack], true, false)
            end
        end
    end

    function Engine.home()
        if dialog_thread and #nav_stack > 1 then
            clear_current_dialog_slot()
            local home_dialog = nav_stack[1]
            if is_registered(home_dialog) then
                nav_stack = { home_dialog }
                Engine.show(home_dialog, true, true)
            else
                U.warn('Home dialog is no longer registered.')
            end
        end
    end

    local function handler_loop()
        local last_time = os.clock()
        while true do
            local ok, err = pcall(function()
                wait(0)
                local now = os.clock()
                local dt = now - last_time
                last_time = now
                local current_id = sampGetCurrentDialogId and sampGetCurrentDialogId() or 0
                if current_id > 0 then
                    local d = active_dialogs[current_id]
                    if d and d.onUpdate then U.safe_call(d.onUpdate, d, dt) end
                    local result, button, list, input = sampHasDialogRespond(current_id)
                    if result then
                        if d then
                            d:__process_response(button, list, input)
                            if not d._isBeingUpdated then
                                active_dialogs[current_id] = nil
                            end
                            d._isBeingUpdated = false
                        else
                            active_dialogs[current_id] = nil
                        end
                    end
                end
            end)
            if not ok then U.errorln('CRITICAL ERROR in handler loop: %s', tostring(err)) end
        end
    end

    function Engine.init()
        if not (dialog_thread and dialog_thread:status() ~= 'dead') then
            dialog_thread = lua_thread.create(handler_loop)
        end
    end

    function Engine.stop()
        if dialog_thread and dialog_thread:status() ~= 'dead' then
            dialog_thread:terminate()
            dialog_thread = nil
        end
        local current_id = sampGetCurrentDialogId and sampGetCurrentDialogId() or 0
        if current_id > 0 and active_dialogs[current_id] then
            sampCloseCurrentDialogWithButton(0)
        end
        active_dialogs, nav_stack, registry = {}, {}, {}
    end
    return Engine
end