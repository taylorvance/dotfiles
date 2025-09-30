return {
	{'hrsh7th/nvim-cmp',
		dependencies = {'hrsh7th/cmp-nvim-lsp', 'zbirenbaum/copilot-cmp'},
		event = {'InsertEnter'},
		config = function()
			local cmp = require('cmp')
			cmp.setup({
				snippet = { -- "you must specify a snippet engine"
					expand = function(args)
						vim.snippet.expand(args.body)
					end,
				},
				window = { -- add borders and show documentation
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				mapping = cmp.mapping.preset.insert({
					['<c-space>'] = cmp.mapping.complete(),
					['<c-j>'] = cmp.mapping.select_next_item(),
					['<c-k>'] = cmp.mapping.select_prev_item(),
					['<cr>'] = cmp.mapping.confirm({ select=true }),
					['<esc>'] = cmp.mapping.abort(),
					-- disable tab to avoid conflicts with copilot
					['<tab>'] = nil,
					['<s-tab>'] = nil,
				}),
				sources = cmp.config.sources({
					{ name='copilot' },
					{ name='nvim_lsp' },
				}),
			})
		end,
	},
	{'zbirenbaum/copilot.lua',
		cmd = 'Copilot',
		event = 'InsertEnter',
		config = function()
			require('copilot').setup({
				suggestion = {
					auto_trigger = true,
					keymap = {
						-- accept=tab is handled below
						accept_line = '<c-l>',
					},
				},
				filetypes = {
					yaml = true,
					markdown = true,
					gitcommit = true,
					sh = function()
						-- disable for ".env*" files
						return not string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), '^%.env.*')
					end,
				},
			})

			-- <tab> accepts the copilot suggestion or inserts a tab character if none
			vim.keymap.set("i", "<tab>", function()
				local copilot_suggestion = require('copilot.suggestion')
				if copilot_suggestion.is_visible() then
					copilot_suggestion.accept()
				else
					return "\t"
				end
			end, {expr=true, silent=true})
		end,
	},
	{'zbirenbaum/copilot-cmp',
		dependencies = {'hrsh7th/nvim-cmp', 'zbirenbaum/copilot.lua'},
		config = function()
			require('copilot_cmp').setup()
		end,
	},
	{'CopilotC-Nvim/CopilotChat.nvim',
		dependencies = {'zbirenbaum/copilot.lua', {'nvim-lua/plenary.nvim',branch='master'}},
		build = 'make tiktoken',
		opts = {
			model = 'gpt-4o',
		},
	},
	'tpope/vim-fugitive',
	--'airblade/vim-gitgutter',
	'lewis6991/gitsigns.nvim',
	{'lewis6991/gitsigns.nvim',
		config = function()
			require('gitsigns').setup({
				attach_to_untracked = true,
				on_attach = function(bufnr)
					local gitsigns = package.loaded.gitsigns
					local function map(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = bufnr
						vim.keymap.set(mode, l, r, opts)
					end
					-- Navigate hunks
					map('n', ']c', function()
					  if vim.wo.diff then
						vim.cmd.normal({']c', bang = true})
					  else
						gitsigns.nav_hunk('next')
					  end
					end)
					map('n', '[c', function()
					  if vim.wo.diff then
						vim.cmd.normal({'[c', bang = true})
					  else
						gitsigns.nav_hunk('prev')
					  end
					end)
					-- Stage/reset
					map('n', '<leader>hs', gitsigns.stage_hunk)
					map('n', '<leader>hr', gitsigns.reset_hunk)
					map('v', '<leader>hs', function()
					  gitsigns.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
					end)
					map('v', '<leader>hr', function()
					  gitsigns.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
					end)
					map('n', '<leader>hS', gitsigns.stage_buffer)
					map('n', '<leader>hR', gitsigns.reset_buffer)
					-- Preview hunk
					map('n', '<leader>hp', gitsigns.preview_hunk)
					map('n', '<leader>hi', gitsigns.preview_hunk_inline)
					-- Show blame
					map('n', '<leader>hb', function()
					  gitsigns.blame_line({ full = true })
					end)
					-- Show diff
					map('n', '<leader>hd', gitsigns.diffthis)
					map('n', '<leader>hD', function()
					  gitsigns.diffthis('~')
					end)
					--[[
					map('n', '<leader>hQ', function() gitsigns.setqflist('all') end)
					map('n', '<leader>hq', gitsigns.setqflist)
					-- Toggles
					map('n', '<leader>tb', gitsigns.toggle_current_line_blame)
					map('n', '<leader>td', gitsigns.toggle_deleted)
					map('n', '<leader>tw', gitsigns.toggle_word_diff)
					-- Text object
					map({'o', 'x'}, 'ih', gitsigns.select_hunk)
					--]]
				end
			})
		end,
	},
	'jeetsukumaran/vim-indentwise',
	{'nvim-lualine/lualine.nvim', --.TODO: show Lazy status updates https://youtu.be/6pAG3BHurdM?si=GWEB_1be31_UZHZM&t=2465
		dependencies = {'nvim-tree/nvim-web-devicons', 'nvim-lua/lsp-status.nvim'},
		opts = {
			options = {
				theme = 'tokyonight',
			},
			sections = {
				lualine_b = {
					{'branch',
						on_click = function()
							-- open git fugitive
							vim.cmd('G')
						end,
					},
					'diff',
					{'diagnostics',
						on_click = function(_, _, mod)
							if mod:find('s') then
								-- open telescope diagnostics
								require('telescope.builtin').diagnostics()
							else
								-- toggle diagnostics
								vim.diagnostic.enable(not vim.diagnostic.is_enabled())
							end
						end,
					},
				},
				lualine_c = {{'filename', path=1}},
				lualine_x = {
					{'lsp_status',
						icon = '',
						symbols = {
							spinner = {'⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'},
							done = '✓',
							separator = ',',
						},
						on_click = function(_, _, mod)
							if mod:find('s') then
								-- restart LSP
								vim.cmd('LspRestart')
							else
								-- open LSP info
								vim.cmd('LspInfo')
							end
						end,
					},
					'filetype',
				},
			},
		},
	},
	{'williamboman/mason.nvim',--.TODO: review josean https://www.youtube.com/watch?v=6pAG3BHurdM&t=3647s
		dependencies = {'williamboman/mason-lspconfig.nvim','neovim/nvim-lspconfig'},
		config = function()
			-- Set up Mason (LSP installer).
			require('mason').setup()

			-- Set up Mason-LSPConfig bridge.
			local lspconfig = require('lspconfig')
			local util = require('lspconfig.util')
			require('mason-lspconfig').setup({
				--                   Python    JS      PHP            C#          Vim     Lua      HTML
				ensure_installed = {'pyright','ts_ls','intelephense','omnisharp','vimls','lua_ls','html'},
				automatic_installation = true,
				-- Set up LSP servers after installation.
				handlers = {
					['intelephense'] = function()
						lspconfig.intelephense.setup({
							settings = {
								intelephense = {
									environment = {shortOpenTag=true},
									stubs = {
										-- 2025-03-20 defaults per https://github.com/bmewburn/intelephense-docs/blob/master/gettingStarted.md#environment
										'apache','bcmath','bz2','calendar','com_dotnet','Core','ctype','curl','date','dba','dom','enchant','exif','FFI','fileinfo','filter','fpm','ftp','gd','gettext','gmp','hash','iconv','imap','intl','json','ldap','libxml','mbstring','meta','mysqli','oci8','odbc','openssl','pcntl','pcre','PDO','pdo_ibm','pdo_mysql','pdo_pgsql','pdo_sqlite','pgsql','Phar','posix','pspell','readline','Reflection','session','shmop','SimpleXML','snmp','soap','sockets','sodium','SPL','sqlite3','standard','superglobals','sysvmsg','sysvsem','sysvshm','tidy','tokenizer','xml','xmlreader','xmlrpc','xmlwriter','xsl','Zend OPcache','zip','zlib',
										'mongodb', -- for "Undefined class \MongoDB\..."
										'random', -- for rand() and friends
									},
								},
							},
						})
					end,
					['lua_ls'] = function()
						lspconfig.lua_ls.setup({
							settings = {
								Lua = {
									diagnostics = {
										globals = {'vim'}, -- recognize vim as a global variable
									},
								},
							},
						})
					end,
					['omnisharp'] = function()
						-- alternatively, make omnisharp.json with: {"RoslynExtensionsOptions":{"enableAnalyzersSupport":true},"FormattingOptions":{"enableEditorConfigSupport":true}}
						lspconfig.omnisharp.setup({
							settings = {
								RoslynExtensionsOptions = {
									EnableAnalyzersSupport = true,
								},
								FormattingOptions = {
									EnableEditorConfigSupport = true,
								},
							},
						})
					end,
					['pyright'] = function()
						lspconfig.pyright.setup({
							before_init = function(_, config)
								local root_dir = config.root_dir or util.find_git_ancestor(vim.fn.getcwd())
								config.settings = config.settings or {}
								config.settings.python = config.settings.python or {}
								-- Try uv first
								local uv_python = vim.fn.system("uv venv --python"):gsub("%s+$", "")
								if vim.fn.filereadable(uv_python) == 1 then
									config.settings.python.pythonPath = uv_python
									return
								end
								-- Try `.venv/bin/python`
								local local_venv = util.path.join(root_dir, ".venv", "bin", "python")
								if vim.fn.filereadable(local_venv) == 1 then
									config.settings.python.pythonPath = local_venv
									return
								end
								-- Fallback to system python
								config.settings.python.pythonPath = vim.fn.exepath("python3")
							end,
						})
					end,
					-- Default handler for LSP servers that don't have a dedicated handler above.
					function(server_name)
						lspconfig[server_name].setup({})
					end,
				},
			})
		end,
	},
	'preservim/nerdcommenter',
	'tpope/vim-repeat',
	'tpope/vim-surround',
	{'nvim-telescope/telescope.nvim',
		tag = '0.1.8',
		dependencies = {
			'nvim-lua/plenary.nvim',
			{'nvim-telescope/telescope-fzf-native.nvim', build='make'},
			'nvim-tree/nvim-web-devicons',
		},
		config = function()
			local telescope = require('telescope')
			local actions = require('telescope.actions')

			telescope.setup({
				defaults = {
					path_display = {'shorten'}, -- smart or shorten
					dynamic_preview_title = true,
					mappings = {
						i = {
							['<esc>'] = actions.close, -- instead of requiring double-esc
							['<c-k>'] = actions.move_selection_previous,
							['<c-j>'] = actions.move_selection_next,
						},
					},
				},
			})

			telescope.load_extension('fzf')
		end,
	},
	{'nvim-telescope/telescope-ui-select.nvim',
		--[[
		dependencies = {'nvim-telescope/telescope.nvim'},
		config = function()
			require('telescope-ui-select').setup()
			require('telescope').load_extension('ui_select')
		end,
		--]]
	},
	--.TODO: look into Trouble for lsp diag mgmt https://youtu.be/6pAG3BHurdM?si=boM5AtmHsM1y7QFz&t=4384
	{'folke/tokyonight.nvim', lazy=false, priority=1000}, -- colorschemes should be loaded first
	{'nvim-treesitter/nvim-treesitter', build=':TSUpdate'},--.TODO: see josean's options https://youtu.be/6pAG3BHurdM?si=sKDNN2tci4_Hmv89&t=2723
	{'folke/trouble.nvim',
		cmd = 'Trouble',
		opts = {
			focus = true,
			open_no_results = true,
			keys = {
				['<cr>'] = 'jump_close',
				['<esc>'] = 'close',
				['<c-b>'] = { -- 2025-04-08 copied from "gb" key in https://github.com/folke/trouble.nvim/tree/main?tab=readme-ov-file#setup
					action = function(view)
						view:filter({buf=0},{toggle=true})
					end,
					desc = "Toggle Current Buffer Filter",
				},
				-- FYI "s" toggles severity filter
				-- FYI "gb" toggles buffer filter (see <c-b> above)
			},
		},
	},
}
