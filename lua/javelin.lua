local M = {}

M.server_active = false
M.current_file = nil
M.server_port = 8081
M.job_id = nil

function M.setup()
	vim.api.nvim_create_autocmd("BufReadCmd", {
		pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp" },
		callback = function()
			local filename = vim.api.nvim_buf_get_name(0)
			M.job_id = vim.fn.jobstart({ "sxiv", "-a", filename })
		end,
	})

	vim.api.nvim_create_autocmd("BufReadCmd", {
		pattern = { "*.pdf" },
		callback = function()
			local filename = vim.api.nvim_buf_get_name(0)
			M.job_id = vim.fn.jobstart({ "zathura", filename })
		end,
	})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			if M.server_active then
				vim.fn.jobstop(M.job_id)
			end
		end,
	})

	vim.api.nvim_create_user_command("SxivHelp", function()
		print("+ | Zoom in")
		print("- | Zoom out")
		print("= | Zoom to 100%")
		print("hjkl | Move when zoomed in")
		print("HJKL | Snap to edge")
		print("w | Fit window")
		print("e | Fit width in window")
		print("E | Fit height in window")
		print("> | Rotate 90 deg right")
		print("< | Rotate 90 deg left")
		print("? | Rotate 180 deg")
		print("| | Invert in x axis")
		print("_ | Invert in y axis")
		print("Ctrl + space | Toggle playing gif")
	end, {})
end

return M
