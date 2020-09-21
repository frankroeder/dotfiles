lua require('lsp')
let g:diagnostic_enable_underline = 0
let g:diagnostic_auto_popup_while_jump = 1
let g:diagnostic_insert_delay = 1
highlight! LspDiagnosticsError ctermfg=Red guifg=#e06c75
highlight! LspDiagnosticsWarning ctermfg=Yellow guifg=#abb2bf
call sign_define("LspDiagnosticsErrorSign", {"text" : "●", "texthl" : "LspDiagnosticsError"})
call sign_define("LspDiagnosticsWarningSign", {"text" : "●", "texthl" : "LspDiagnosticsWarning"})
call sign_define("LspDiagnosticsInformationSign", {"text" : "●", "texthl" : "LspDiagnosticsInformation"})
call sign_define("LspDiagnosticsHintSign", {"text" : "●", "texthl" : "LspDiagnosticsHint"})

nmap <silent> gn :NextDiagnosticCycle<CR>
nmap <silent> gp :PrevDiagnosticCycle<CR>
