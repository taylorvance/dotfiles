return {
	{'hrsh7th/nvim-cmp',
		dependencies = {'hrsh7th/cmp-nvim-lsp'},
		event = {'InsertEnter'},
		config = function()
			local cmp = require('cmp')
			local sources = { { name = 'nvim_lsp', priority = 80 } }

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
				experimental = {ghost_text=true},
				completion = {keyword_length=0},  -- Trigger even with no characters typed
				mapping = cmp.mapping.preset.insert({
					['<c-space>'] = cmp.mapping.complete(),
					['<c-j>'] = cmp.mapping.select_next_item(),
					['<c-k>'] = cmp.mapping.select_prev_item(),
					['<cr>'] = cmp.mapping.confirm({ select=true }),
					['<esc>'] = cmp.mapping.abort(),
				}),
				sources = cmp.config.sources(sources),
				performance = {
					debounce = 150,
					throttle = 60,
					fetching_timeout = 3000,
				},
			})
		end,
	},
	{'meeehdi-dev/bropilot.nvim', -- ollama-based code completion (copilot-style inline suggestions)
		--[[
		-- `brew install ollama` to install Ollama
		-- `ollama pull [model]` to download a model
		-- `ollama serve` to start the server
		-- `ollama list` to see available models
		--]]
		dependencies = {'nvim-lua/plenary.nvim', 'j-hui/fidget.nvim'},
		opts = {
			provider = 'ollama',
			--model = 'deepseek-coder-v2:latest',
			model = 'qwen2.5-coder:1.5b',
			--model = 'codellama:7b-code',
			keymap = {
				suggest = '<c-y>',
				accept_word = '<right>',
				accept_line = '<s-right>',
				accept_block = '<tab>',
			},
		},
	},
	'tpope/vim-fugitive',
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
								-- open snacks diagnostics
								Snacks.picker.diagnostics()
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
	{'mfussenegger/nvim-lint',
		event = {'BufReadPost','BufNewFile'},
		dependencies = {
			{"rshkarin/mason-nvim-lint", opts={ensure_installed={"eslint_d","ruff"}}},
		},
		config = function()
			local lint = require('lint')
			lint.linters_by_ft = {
				python = {'ruff'},
				javascript = {'eslint_d'},
				javascriptreact = {'eslint_d'},
				typescript = {'eslint_d'},
				typescriptreact = {'eslint_d'},
			}
			vim.api.nvim_create_autocmd({'BufWritePost'}, {
				callback = function() lint.try_lint() end,
			})
		end,
	},
	'tpope/vim-repeat',
	'tpope/vim-surround',
	{'folke/snacks.nvim',
		priority = 1000,
		lazy = false,
		opts = {
			picker = {
				enabled = true,
				-- Include hidden files (for dotfiles repos)
				hidden = true,
				win = {
					input = {
						keys = {
							['<esc>'] = { 'close', mode = { 'n', 'i' } },
							['<c-j>'] = { 'list_down', mode = { 'i', 'n' } },
							['<c-k>'] = { 'list_up', mode = { 'i', 'n' } },
						},
					},
				},
			},
		},
	},
	{'folke/tokyonight.nvim', lazy=false, priority=1000}, -- colorschemes should be loaded first
	{"nvim-tree/nvim-tree.lua",
		dependencies = {"nvim-tree/nvim-web-devicons"},
		version = "*",
		lazy = false,
		config = function()
			require("nvim-tree").setup {}
		end,
	},
	{'nvim-treesitter/nvim-treesitter',
		build = ':TSUpdate',
		config = function()
			require('nvim-treesitter.configs').setup({
				-- Install parsers for these languages
				ensure_installed = {
					'vim', 'vimdoc', 'lua',
					'python', 'javascript', 'typescript', 'tsx',
					'html', 'css', 'json', 'yaml',
					'php', 'c_sharp',
					'bash', 'markdown', 'regex',
				},
				auto_install = true, -- auto-install missing parsers when entering buffer
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = false,
				},
				indent = {
					enable = true,
				},
				incremental_selection = {
					enable = true,
					keymaps = {
						init_selection = '<cr>',
						node_incremental = '<cr>',
						node_decremental = '<bs>',
						scope_incremental = '<c-s>',
					},
				},
			})
		end,
	},
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
