local C = require('easy_dialog.constants')

local U = {}

function U.warn(msg, ...)
    print(('[easy-dialog] Warning: '..tostring(msg)):format(...))
end

function U.errorln(msg, ...)
    print(('[easy-dialog] Error: '..tostring(msg)):format(...))
end

function U.safe_call(fn, ...)
    if type(fn) ~= 'function' then return true end
    local ok, res = pcall(fn, ...)
    if not ok then U.errorln('in user callback: %s', tostring(res)) end
    return ok, res
end

function U.truncate(text, limit, name)
    text = tostring(text or '')
    if #text > limit then
        U.warn("'%s' exceeds limit of %d chars. Truncating.", name or 'text', limit)
        return text:sub(1, limit)
    end
    return text
end

local function clamp_tab_cols(s)
    local cols, n = {}, 0
    for col in tostring(s):gmatch('[^\t]+') do
        n = n + 1
        cols[#cols+1] = U.truncate(col, C.LIMITS.TAB_COL, 'Tablist column')
        if n >= C.LIMITS.TAB_COLS then break end
    end
    return table.concat(cols, '\t')
end

function U.clamp_tablist_row(line)
    return U.truncate(clamp_tab_cols(line), C.LIMITS.TAB_ROW, 'Tablist row')
end

function U.format_content(content, LIMIT_TOTAL)
    if type(content) ~= 'table' then
        return tostring(content or '')
    end
    local rows = {}
    for _, item in ipairs(content) do
        if type(item) == 'table' then
            if item.text then
                rows[#rows+1] = tostring(item.text)
            else
                rows[#rows+1] = table.concat(item, '\t')
            end
        else
            rows[#rows+1] = tostring(item)
        end
    end
    local text = table.concat(rows, '\n')
    return U.truncate(text, LIMIT_TOTAL or C.LIMITS.TOTAL_TEXT, 'Dialog content')
end

return U