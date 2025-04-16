local ICON_TYPE = { "history", "alt_font", "emoji", "html_colors", "nerd_font", "symbols" }
local M = {}

local function get_icons_history()
	local hist = io.open(M.history_path, "r")
	if not hist then
		return { icons = {}, spaces = 0, sorted_keys = {} }
	end

	local data = {}
	local keys = {}

	for line in hist:lines() do
		local columns = vim.split(line, "%s+")

		if #columns > 2 then
			local key = table.concat(columns, " ", 2)
			data[key] = { columns[1], columns[2] }
			table.insert(keys, 1, key)
		end
	end
	hist:close()
	return { icons = data, spaces = 0, sorted_keys = keys }
end

-- vim.ui.select functionality
local function insert_user_choice_history(choice)
	local columns = vim.split(choice, "%s+")
	local key = table.concat(columns, " ", 3)
	if vim.tbl_get(M.icon_type_data, "history", "icons", key) then
		return
	end

	M.icon_type_data.history.icons[key] = { columns[1], columns[2] }
	local hist = io.open(M.history_path, "a")
	if not hist then
		return
	end
	hist:write(choice, "\n")
	hist:close()
end

local function insert_user_choice_normal(choice)
	if choice then
		local split = vim.split(choice, " ")
		insert_user_choice_history(choice)

		vim.api.nvim_put({ split[1] }, "", false, true)
	end
end

local function insert_user_choice_insert(choice)
	if choice then
		local split = vim.split(choice, " ")
		insert_user_choice_history(choice)

		local current_line = vim.api.nvim_get_current_line()
		local cursor_col = vim.api.nvim_win_get_cursor(0)[2]

		if cursor_col + 1 >= #current_line then
			vim.api.nvim_put({ split[1] }, "", true, true)
		else
			vim.api.nvim_put({ split[1] }, "", false, false)
		end

		vim.api.nvim_feedkeys("a", "t", false)
	end
end

local function yank_user_choice_normal(choice)
	if choice then
		local split = vim.split(choice, " ")
		insert_user_choice_history(choice)

		vim.schedule(function()
			vim.cmd("let @+='" .. split[1] .. "'")
		end)
	end
end

local function custom_ui_select(items, prompt, callback)
	vim.ui.select(items, {
		prompt = prompt,
		kind = "icon_picker",
	}, callback)
end

-- list functionality
--- insert a key val pair into a list with an arbitrary amount of spaces
-- @param  map: hash map of pairs to insert into list
-- @param  num_spaces: number of spaces to insert between key and val
local function push_map(type_key, map, num_spaces, cur_list)
	cur_list = cur_list or {}
	if type_key == "history" then
		if not M.icon_type_data.history.sorted_keys then
			return
		end
		for _, key in ipairs(M.icon_type_data.history.sorted_keys) do
			local val = map[key]
			key = string.format("%-16s", val[2]) .. key
			val = val[1]
			table.insert(cur_list, table.concat({ val, key }, string.rep(" ", 8 - vim.fn.strdisplaywidth(val))))
		end
		return cur_list
	end

	local spaces = string.rep(" ", num_spaces)
	type_key = string.format("%-16s", type_key)
	if type_key == "emoji" then
		for key, val in pairs(map) do
			table.insert(
				cur_list,
				table.concat({ val, type_key .. key }, string.rep(" ", 8 - vim.fn.strdisplaywidth(val)))
			)
		end
		return cur_list
	end

	for key, val in pairs(map) do
		table.insert(cur_list, table.concat({ val, type_key .. key }, spaces))
	end

	return cur_list
end

function Split(s, delimiter) -- from code grep
	local result = {}
	for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
		if #match > 0 then
			table.insert(result, match)
		end
	end
	return result
end

local function generate_icon_type_data()
	return {
		["history"] = get_icons_history(),
		["alt_font"] = {
			icons = require("icon-picker.icons.alt-fonts"),
			spaces = 6,
		},
		["emoji"] = {
			icons = require("icon-picker.icons.emoji-list"),
			spaces = 6,
		},
		["nerd_font"] = {
			icons = require("icon-picker.icons.nf-icon-list"),
			spaces = 7,
		},
		["nerd_font_v3"] = {
			icons = require("icon-picker.icons.nf-v3-icon-list"),
			spaces = 7,
		},
		["symbols"] = {
			icons = require("icon-picker.icons.symbol-list"),
			spaces = 7,
		},
		["html_colors"] = {
			icons = require("icon-picker.icons.html-colors"),
			spaces = 6,
		},
	}
end

local function generate_api()
	local API_table = {
		-- need better variable name
		["Normal"] = insert_user_choice_normal,
		["Insert"] = insert_user_choice_insert,
		["Yank"] = yank_user_choice_normal,
	}

	-- loops through the table & create user commands
	for command, callback in pairs(API_table) do
		vim.api.nvim_create_user_command("IconPicker" .. command, function(opts)
			local args = Split(opts.args, " ") -- split command arguments
			local desc = "Pick"

			if #args == 0 then
				args = ICON_TYPE
			end

			local item_list = {}
			for _, argument in ipairs(args) do
				local cur_tbl = M.icon_type_data[argument]
				if cur_tbl == nil then
					return
				end

				-- push icon results into item_list
				item_list = push_map(argument, cur_tbl["icons"], cur_tbl["spaces"], item_list)
				desc = desc .. " " .. argument
			end

			custom_ui_select(item_list, desc, callback)
		end, {
			nargs = "?",
			complete = function()
				return ICON_TYPE
			end,
		})
	end
end

M.setup = function(opts)
	M.history_path = opts.history_path or vim.fn.stdpath("data") .. "/icon-picker-history.txt"
	M.icon_type_data = generate_icon_type_data()
	generate_api()
end

return M
