-- wezterm --config-file tools/Test-Clipboard.lua show-keys
-- システムのクリップボードやペインには触れず、貼り付け先への受け渡しを確かめる。
local wezterm = require 'wezterm'
local root = wezterm.config_dir .. '/../kitty_ja/'
local settings = {
  shell_program = 'C:/Program Files/PowerShell/7/pwsh.exe',
  clipboard_image_script = 'C:/test user/clipboard-image.ps1',
}
local response, pasted, performed, notifications, child_args
local mock = {
  run_child_process = function(args)
    child_args = args
    return response.success, wezterm.json_encode(response.result), response.stderr or ''
  end,
  json_parse = wezterm.json_parse,
  log_error = function() end,
  action_callback = function(handler) return handler end,
  action = setmetatable({}, {
    __index = function(_, name)
      return function(value) return { name = name, value = value } end
    end,
  }),
}
local window = {
  perform_action = function(_, action) performed = action end,
  toast_notification = function() notifications = notifications + 1 end,
  get_selection_text_for_pane = function() return 'selected text' end,
}
local pane = { send_paste = function(_, text) pasted = text end }
local clipboard
local environment = setmetatable({
  require = function(name)
    if name == 'wezterm' then return mock end
    if name == 'kitty_ja.settings' then return settings end
    if name == 'kitty_ja.state' then return {} end
    if name == 'kitty_ja.clipboard' then return clipboard end
    error('Unexpected module: ' .. name)
  end,
}, { __index = _G })
clipboard = assert(loadfile(root .. 'clipboard.lua', 't', environment))()
local panes = assert(loadfile(root .. 'panes.lua', 't', environment))()

local function reset(result, success)
  response = { success = success ~= false, result = result }
  pasted, performed, notifications, child_args = nil, nil, 0, nil
end

reset { kind = 'image', path = 'C:\\test user\\画像.png' }
panes.paste_from_clipboard(window, pane)
assert(pasted == '"C:/test user/画像.png" ', 'Image path was not quoted or preserved')
assert(not performed and notifications == 0, 'Image also triggered text paste or error')
assert(child_args[1] == settings.shell_program and child_args[5] == '-STA', 'Missing STA PowerShell')
assert(child_args[9] == settings.clipboard_image_script, 'Script path was split or changed')

reset { kind = 'text' }
panes.paste_from_clipboard(window, pane)
assert(not pasted and performed.name == 'PasteFrom' and performed.value == 'Clipboard', 'Text paste changed')

reset({}, false)
panes.paste_from_clipboard(window, pane)
assert(not pasted and not performed and notifications == 1, 'Failed export was silently pasted')

reset { kind = 'image', path = 'C:\\test user\\画像.png' }
panes.paste_from_selection(window, pane)
assert(pasted == 'selected text' and not child_args, 'Selected text lost priority')

window.get_selection_text_for_pane = function() return '' end
reset { kind = 'image', path = 'C:\\test user\\画像.png' }
panes.paste_from_selection(window, pane)
assert(pasted == '"C:/test user/画像.png" ', 'Shift+Insert did not fall back to image paste')

print('PASS: image/text paste, Unicode/spaces, errors, and selection priority')
return {}
