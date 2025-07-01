local M = {}

M.server_active = false
M.current_file = nil
M.server_port = 8081
M.server_job_id = nil

function M.setup()
    M.server_start()
    vim.api.nvim_create_autocmd("BufReadCmd", {
        pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.pdf" },
        callback = function()
            local filename = vim.api.nvim_buf_get_name(0)
            vim.cmd("let tobedeleted = bufnr('%') | b# | exe \"bd! \" . tobedeleted")

            if not M.server_active then
                M.launch(filename)
            elseif M.current_file == filename then
                M.close_tab()
                return
            else
                M.close_tab()
                M.launch(filename)
            end
        end,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            if M.server_active then
                M.close_tab()
                M.stop_server()
            end
        end,
    })

    vim.api.nvim_create_user_command("ImagePreviewStatus", function()
        require("config.images").status()
    end, {})
end

function M.server_start()
    local server_js_path = vim.fn.expand("%:p:h:h") .. "/app/server.js"
    -- vim.fn.expand("~/plugins/javelin.nvim/app/server.js")
    print("Server started at", server_js_path)
    M.server_job_id = vim.fn.jobstart(string.format("node %s", server_js_path), {
        detach = true,
        on_exit = function()
            M.server_active = false
            M.current_file = nil
        end,
    })
end

function M.server_stop()
    if M.server_job_id then
        vim.fn.jobstop(M.server_job_id)
        M.server_job_id = nil
    end
end

function M.launch(filename)
    M.current_file = filename
    M.server_active = true
    local abs_path = vim.fn.fnamemodify(filename, ":p")
    local url = "http://localhost:8081/new-tab" .. abs_path:gsub(" ", "%%20")
    vim.fn.jobstart({ "curl", "-X", "POST", url })
end

function M.close_tab()
    M.server_active = false
    M.current_file = nil
    vim.fn.jobstart({ "curl", "-X", "POST", "http://localhost:8081/close-tab" })
end

function M.status()
    print(
        string.format(
            "Server: %s | File: %s | Port: %d",
            M.server_active and "Running" or "Stopped",
            M.current_file or "None",
            M.server_port
        )
    )
end

return M
