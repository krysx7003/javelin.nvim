local javelin ={}

javelin.server_active = false
javelin.current_file = nil
javelin.server_port = 8081
javelin.server_job_id = nil

function javelin.setup()
    vim.api.nvim_create_autocmd("BufReadCmd", {
      pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp","*.pdf" },
      callback = function()
        local filename = vim.api.nvim_buf_get_name(0)
        vim.cmd("let tobedeleted = bufnr('%') | b# | exe \"bd! \" . tobedeleted")

        if not javelin.server_active then
            javelin.launch(filename)

        elseif javelin.current_file == filename then
            javelin.stop_server()
            return

        else
            javelin.stop_server()
            vim.defer_fn(function()
                javelin.launch(filename)
            end, 200)
        end

      end
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            if javelin.server_active then
                javelin.stop_server()
            end
        end
    })

    vim.api.nvim_create_user_command('ImagePreviewStatus', function()
            require('config.images').status()
        end, {})
end

function javelin.launch(filename)
    javelin.current_file = filename
    local dir = vim.fn.fnamemodify(filename, ":h")
    local abs_path = vim.fn.fnamemodify(filename, ":p")
    local server_js_path = vim.fn.stdpath('config') .. '/lua/config/'

    javelin.server_job_id = vim.fn.jobstart(string.format(
        'node "%s/app/server.js" %s',
        server_js_path,
        abs_path
    ), {
        cwd = dir,
        detach = true,
    })

    javelin.server_active = true
end

function javelin.stop_server()
    if javelin.server_job_id then
        vim.fn.jobstop(javelin.server_job_id)
        javelin.server_job_id = nil
    end

    javelin.server_active = false
    javelin.current_file = nil
end

function javelin.status()
    print(string.format("Server: %s | File: %s | Port: %d",
        javelin.server_active and "Running" or "Stopped",
        javelin.current_file or "None",
        javelin.server_port))
end

return javelin
