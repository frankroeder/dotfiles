vim.opt_local.iskeyword:append { ":", "-" }
vim.opt_local.indentexpr = ""
vim.opt_local.wrap = true
vim.opt_local.linebreak = true

local function latex_clipboard_image()
  -- Create `figures` directory if it doesn't exist
  local img_dir = vim.fn.getcwd() .. "/figures"
  if vim.fn.isdirectory(img_dir) == 0 then
    vim.fn.mkdir(img_dir)
  end

  -- Default filename
  local index = 1
  local file_name = "image" .. index
  local file_ext = "png" -- Default extension

  -- Generate unique filename
  local file_path = img_dir .. "/" .. file_name .. "." .. file_ext
  while vim.fn.filereadable(file_path) == 1 do
    index = index + 1
    file_name = "image" .. index
    file_path = img_dir .. "/" .. file_name .. "." .. file_ext
  end

  print("Debug - Saving to: " .. file_path)

  -- Simplified AppleScript that tries each format directly
  local script_path = os.tmpname()
  local script_file = io.open(script_path, "w")

  script_file:write([[
    set outputPath to "]] .. file_path .. [["

    set savedImage to false
    set imageFormat to "png"

    -- Try PNG format
    try
      set imageData to the clipboard as «class PNGf»
      set imageFormat to "png"
      set savedImage to true
    on error
      -- Try PDF format
      try
        set imageData to the clipboard as «class PDF »
        set imageFormat to "pdf"
        set savedImage to true
      on error
        -- Try JPEG format
        try
          set imageData to the clipboard as JPEG picture
          set imageFormat to "jpg"
          set savedImage to true
        on error
          -- Try TIFF format
          try
            set imageData to the clipboard as TIFF picture
            set imageFormat to "tiff"
            set savedImage to true
          end try
        end try
      end try
    end try

    if savedImage then
      -- Ensure the file extension matches the actual format
      if imageFormat is not "png" then
        set outputPath to text 1 thru -5 of outputPath & "." & imageFormat
      end if

      -- Write the file with proper error handling
      try
        set fileRef to open for access outputPath with write permission
        set eof of fileRef to 0
        write imageData to fileRef
        close access fileRef
        return "success:" & outputPath
      on error errMsg
        try
          close access file outputPath
        end try
        return "error:Failed to write image - " & errMsg
      end try
    else
      return "error:No image data found in clipboard"
    end if
  ]])

  script_file:close()

  -- Execute the AppleScript
  local result = vim.fn.system("osascript " .. script_path)
  os.remove(script_path)

  print("Debug - AppleScript result: " .. result)

  if result:match "^error:" then
    vim.api.nvim_err_writeln("Error: " .. result:sub(7))
    return
  end

  -- Extract the actual file path and extension from the result
  local actual_path = result:match "success:(.*)"
  if actual_path then
    file_ext = vim.fn.fnamemodify(actual_path, ":e")
    file_name = vim.fn.fnamemodify(actual_path, ":t:r")
  end

  -- Get caption from current line
  local caption = vim.fn.getline "."

  -- Create the LaTeX figure code
  local figure_text = "\\begin{figure}[htbp]\n"
    .. "    \\centering\n"
    .. "    \\includegraphics[width=0.8\\textwidth]{./figures/"
    .. file_name
    .. "."
    .. file_ext
    .. "}\n"
    .. "    \\caption{"
    .. caption
    .. "}\n"
    .. "    \\label{fig:"
    .. file_name
    .. "}\n"
    .. "\\end{figure}\n"

  -- Replace current line with the figure environment
  local lines = vim.split(figure_text, "\n")
  vim.api.nvim_del_current_line()
  vim.api.nvim_put(lines, "l", true, true)

  -- Position cursor at end of \caption{} for editing
  vim.cmd "normal! 4k5w"
  vim.cmd "write"
end

-- Create the command
vim.api.nvim_create_user_command("LatexClipboardImage", function()
  latex_clipboard_image()
end, {})
