return function(C, U, Engine)
    local Dialog = {}
    Dialog.__index = Dialog
    Dialog.__name  = 'Dialog'
    local Dialog_mt = { __index = Dialog }
    Dialog_mt.__tostring = function(self)
        return ('Dialog(ID: %s, Caption: "%s")'):format(tostring(self.id or 'auto'), self.caption or '')
    end
    Dialog_mt.__call = function(self) Engine.show(self) end

    function Dialog.new()
        local self = setmetatable({}, Dialog_mt)
        self.caption       = ''
        self.dialog_style  = 'msgbox'
        self.button1       = 'OK'
        self.button2       = ''
        self.launch_mode   = C.LaunchMode.STANDARD
        self._items        = {}
        self._headers      = nil
        self._itemsPerPage = 0
        self._currentPage  = 1
        self._totalPages   = 1
        self._isPaginated  = false
        self._isBeingUpdated = false
        self.onResponse = nil
        self.onShow = nil
        self.onUpdate = nil
        self.onStart = nil
        self.onProcessResult = nil
        return self
    end

    function Dialog:setId(id)
        if type(id) ~= 'number' or id < 1 or id > C.MAX_DIALOG_ID then
            U.warn('Invalid dialog ID (%s).', tostring(id))
            return self
        end
        if Engine.is_active(id) then
            U.warn('Dialog ID %d is already in use by an active dialog.', id)
        end
        self.id = id
        return self
    end

    function Dialog:setCaption(caption) self.caption = caption; return self end

    function Dialog:setButtons(btn1, btn2)
        self.button1 = (btn1 and #btn1 > 0) and btn1 or 'OK'
        self.button2 = btn2 or ''
        return self
    end

    function Dialog:setStyle(style)
        if not C.STYLE_MAP[style] then
            U.warn("Unknown style '%s'.", tostring(style))
            self.dialog_style = 'msgbox'
        else
            self.dialog_style = style
        end
        return self
    end

    function Dialog:setContent(text)
        self._items = { text }
        self._isPaginated = false
        return self
    end

    function Dialog:setHeaders(headers)
        if headers and type(headers) ~= 'table' then
            U.warn('Invalid type for setHeaders: %s.', type(headers))
            self._headers = nil
        else
            self._headers = headers
        end
        return self
    end

    function Dialog:setItems(items_table)
        self._items = (type(items_table) == 'table' or type(items_table) == 'function') and items_table or {}
        self._isPaginated = true
        return self
    end

    function Dialog:setItemsPerPage(count)
        if type(count) ~= 'number' or count < 0 then
            U.warn('Invalid items per page count (%s).', tostring(count))
            self._itemsPerPage = 0
        else
            self._itemsPerPage = count
        end
        return self
    end

    function Dialog:setOnResponse(fn) self.onResponse = fn; return self end

    function Dialog:setOnShow(fn) self.onShow = fn; return self end

    function Dialog:setOnUpdate(fn) self.onUpdate = fn; return self end

    function Dialog:setOnStart(fn) self.onStart = fn; return self end

    function Dialog:setOnProcessResult(fn) self.onProcessResult = fn; return self end

    function Dialog:setLaunchMode(mode)
        local valid = false
        for _, v in pairs(C.LaunchMode) do if mode == v then valid = true; break end end
        if not valid then
            U.warn("Invalid launch mode '%s'.", tostring(mode))
            self.launch_mode = C.LaunchMode.STANDARD
        else
            self.launch_mode = mode
        end
        return self
    end

    function Dialog:close(button)
        if not self.id then return end
        if sampSendDialogResponse then
            sampSendDialogResponse(self.id, (button or 1), -1, '')
        else
            sampCloseCurrentDialogWithButton(button or 1)
        end
        Engine.mark_inactive(self.id)
    end

    function Dialog:update()
        if not Engine.is_active(self.id) then return end
        self._isBeingUpdated = true
        Engine.show(self)
    end

    function Dialog:_resolve(v, expect_type)
        if type(v) == 'function' then
            local ok, result = pcall(v, self)
            if not ok then
                U.errorln('resolving function value: %s', tostring(result))
                if expect_type == 'string' then return '' end
                if expect_type == 'table'  then return {} end
                return nil
            end
            return result
        end
        return v
    end

    function Dialog:_validate()
        self.caption = U.truncate(self:_resolve(self.caption, 'string'), C.LIMITS.CAPTION, 'Caption')
        if self.dialog_style == 'input' or self.dialog_style == 'password' then
            local items = self:_resolve(self._items)
            if type(items) == 'table' and items[1] ~= nil then
                local s = tostring(items[1])
                if #s > C.LIMITS.INPUT_TEXT then
                    U.warn('Default input text exceeds limit of %d chars. Truncating.', C.LIMITS.INPUT_TEXT)
                    items[1] = s:sub(1, C.LIMITS.INPUT_TEXT)
                    self._items = items
                end
            end
        end
    end

    function Dialog:_renderContent(cfg)
        local items  = self:_resolve(self._items)
        local header = self:_resolve(self._headers)
        if type(items) ~= 'table' then items = {} end
        if #items == 0 and self._isPaginated then
            return { cfg.EMPTY_LIST_TEXT }
        end

        local function postprocess_tab_rows(content)
            if self.dialog_style == 'tablist' or self.dialog_style == 'tablist_headers' then
                for i = 1, #content do
                    if type(content[i]) == 'string' then
                        content[i] = U.clamp_tablist_row(content[i])
                    elseif type(content[i]) == 'table' and content[i]._is_nav and content[i].text then
                        content[i].text = U.truncate(content[i].text, C.LIMITS.TAB_ROW, 'Nav row')
                    end
                end
            end
        end
        if not self._isPaginated or self._itemsPerPage <= 0 then
            local content = header and { table.concat(header, '\t') } or {}
            for _, it in ipairs(items) do content[#content+1] = self:_resolve(it) end
            postprocess_tab_rows(content)
            return content
        end
        self._totalPages = math.max(1, math.ceil(#items / self._itemsPerPage))
        self._currentPage = math.max(1, math.min(self._currentPage, self._totalPages))
        local content = header and { table.concat(header, '\t') } or {}
        local start_i = (self._currentPage - 1) * self._itemsPerPage + 1
        local end_i   = math.min(start_i + self._itemsPerPage - 1, #items)
        for i = start_i, end_i do content[#content+1] = self:_resolve(items[i]) end
        if #items > 0 then
            if self._currentPage > 1 then
                content[#content+1] = { _is_nav = true, _nav_action = 'prev', text = cfg.PAGINATION_PREV }
            end
            if self._currentPage < self._totalPages then
                content[#content+1] = { _is_nav = true, _nav_action = 'next', text = cfg.PAGINATION_NEXT }
            end
        end
        postprocess_tab_rows(content)
        return content
    end

    function Dialog:_handlePagination(list_zero_based)
        local header_offset = (self.dialog_style == 'tablist_headers' and self._headers) and 1 or 0
        local idx = (list_zero_based or 0) + 1 + header_offset
        local item = (self._lastRenderedContent or {})[idx]
        if type(item) ~= 'table' or not item._is_nav then return false end
        if item._nav_action == 'prev' then
            self._currentPage = self._currentPage - 1
            self:update()
            return true
        elseif item._nav_action == 'next' then
            self._currentPage = self._currentPage + 1
            self:update()
            return true
        end
        return false
    end

    function Dialog:_prepare_for_show(cfg)
        if not self.id then self.id = Engine.allocate_id() end
        if Engine.is_active(self.id) and Engine.get_active(self.id) ~= self then
            U.warn('Dialog ID %d is in use by another dialog.', self.id)
        end
        if not Engine.is_active(self.id) then
            U.safe_call(self.onShow, self)
        end
        self:_validate()
        local content_table = self:_renderContent(cfg)
        self._lastRenderedContent = content_table
        local text = U.format_content(content_table, C.LIMITS.TOTAL_TEXT)
        local caption = self.caption
        if self._isPaginated and self._totalPages > 1 then
            local pagetext = cfg.PAGINATION_TEXT:format(self._currentPage, self._totalPages)
            caption = ('%s (%s)'):format(self.caption, pagetext)
            caption = U.truncate(caption, C.LIMITS.CAPTION, 'Paginated Caption')
        end
        local style = C.STYLE_MAP[self.dialog_style] or 0
        return caption, text, style, self.button1, self.button2
    end

    function Dialog:__process_response(button, list, input)
        if not self.onResponse then return end
        if self:_handlePagination(list) then return end
        local is_list = (self.dialog_style == 'list' or self.dialog_style == 'tablist' or self.dialog_style == 'tablist_headers')
        if is_list and list < 0 then
            U.safe_call(self.onResponse, self, button, -1, input, nil)
            return
        end
        local items = self:_resolve(self._items)
        local abs_index = (list or 0) + 1
        if self._isPaginated and self._itemsPerPage > 0 and type(items) == 'table' and #items > 0 then
            abs_index = (self._currentPage - 1) * self._itemsPerPage + (list or 0) + 1
        end
        local selected_item = (type(items) == 'table') and items[abs_index] or nil
        U.safe_call(self.onResponse, self, button, abs_index, input, selected_item)
    end

    return setmetatable({ new = Dialog.new }, { __call = function(_, ...) return Dialog.new(...) end })
end
