local M = {}

function M.setup()
	return M
end

function M.launch_check(filename)
	M.launch(filename)
end

function M.parse_synctex(cmd)
	local handle = io.popen(cmd)
	if not handle then
		return -1
	end

	local page = 0
	local x = 0
	local y = 0
	local found_valid = false

	for line in handle:lines() do
		if line:match("^Page:") then
			page = tonumber(line:match("%d+")) or 0
		elseif line:match("^x:") and not found_valid then
			local val = tonumber(line:match("[%-%d%.]+"))
			if val and val > 0 then
				x = val
			end
		elseif line:match("^y:") and not found_valid and x ~= 0 then
			local val = tonumber(line:match("[%-%d%.]+"))
			if val and val > 0 then
				y = val
				found_valid = true
			end
		end
	end

	handle:close()
	return page, x, y
end

function M.get_synctex_loc()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1
	local texFile = vim.api.nvim_buf_get_name(0)
	local pdfFile = "main.pdf"

	local pos_in_file = row .. ":" .. col .. ":" .. texFile:gsub(" ", "%%20")
	local cmd = "synctex view -i " .. pos_in_file .. " -o " .. pdfFile:gsub(" ", "%%20")
	local page, x, y = M.parse_synctex(cmd)

	return page, x, y
end

function M.launch(filename)
	local page, x, y = M.get_synctex_loc()
	local abs_path = vim.fn.fnamemodify(filename, ":p")

	local url = "http://localhost:8081/scroll-tab"
		.. abs_path:gsub(" ", "%%20")
		.. "#page="
		.. page
		.. "&x="
		.. x
		.. "&y="
		.. y
	print(url)
	-- vim.fn.jobstart({ "curl", "-X", "POST", url })
end

return M
