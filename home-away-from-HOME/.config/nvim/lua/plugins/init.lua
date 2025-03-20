return {
	{'hrsh7th/nvim-cmp',
		dependencies = {'hrsh7th/cmp-nvim-lsp', 'zbirenbaum/copilot-cmp'},
		event = {'InsertEnter'},
		config = function()
			local cmp = require('cmp')
			cmp.setup({
				snippet = {
					expand = function(args)
						vim.snippet.expand(args.body)
					end,
				},
				window = {
					-- add borders to the cmp window
					completion = cmp.config.window.bordered(),
					-- show documentation in a separate window
					documentation = cmp.config.window.bordered(),
				},
				mapping = cmp.mapping.preset.insert({
					['<c-space>'] = cmp.mapping.complete(),
					['<c-j>'] = cmp.mapping.select_next_item(),
					['<c-k>'] = cmp.mapping.select_prev_item(),
					['<cr>'] = cmp.mapping.confirm({ select=true }),
					['<esc>'] = cmp.mapping.abort(),
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
						accept = '<tab>',
						accept_line = '<c-l>',
					},
				},
			})
		end,
	},
	{'zbirenbaum/copilot-cmp',
		dependencies = {'hrsh7th/nvim-cmp', 'zbirenbaum/copilot.lua'},
		config = function()
			require('copilot_cmp').setup()
		end,
	},
	'tpope/vim-fugitive',
	'airblade/vim-gitgutter',
	{'nvim-lualine/lualine.nvim',
		dependencies = {'nvim-tree/nvim-web-devicons'},
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
				lualine_x = {'filetype'},
			},
		},
	},
	{'williamboman/mason.nvim',
		dependencies = {'williamboman/mason-lspconfig.nvim','neovim/nvim-lspconfig'},
		config = function()
			-- Set up Mason (LSP installer)
			require('mason').setup()
			-- Set up Mason-LSPConfig bridge
			require('mason-lspconfig').setup({
				--                   python    php            c#          vim     lua
				ensure_installed = {'pyright','intelephense','omnisharp','vimls','lua_ls'},
				automatic_installation = true,
			})
			-- Configure LSP servers automatically when they are installed
			local lspconfig = require('lspconfig')
			require('mason-lspconfig').setup_handlers({
				function(server_name)
					lspconfig[server_name].setup({
						settings = {
							intelephense = {
								stubs = {
									-- 2025-03-20 defaults per https://github.com/bmewburn/intelephense-docs/blob/master/gettingStarted.md#environment
									'apache','bcmath','bz2','calendar','com_dotnet','Core','ctype','curl','date','dba','dom','enchant','exif','FFI','fileinfo','filter','fpm','ftp','gd','gettext','gmp','hash','iconv','imap','intl','json','ldap','libxml','mbstring','meta','mysqli','oci8','odbc','openssl','pcntl','pcre','PDO','pdo_ibm','pdo_mysql','pdo_pgsql','pdo_sqlite','pgsql','Phar','posix','pspell','readline','Reflection','session','shmop','SimpleXML','snmp','soap','sockets','sodium','SPL','sqlite3','standard','superglobals','sysvmsg','sysvsem','sysvshm','tidy','tokenizer','xml','xmlreader','xmlrpc','xmlwriter','xsl','Zend OPcache','zip','zlib',
									-- adding mongodb to resolve "Undefined class \MongoDB\..."
									'mongodb',
								},
							},
						},
					})
				end
			})
		end,
	},
	'preservim/nerdcommenter',
	'tpope/vim-repeat',
	'tpope/vim-surround',
	{'nvim-telescope/telescope.nvim',
		tag = '0.1.8',
		dependencies = {'nvim-lua/plenary.nvim'},
		opts = {
			defaults = {
				mappings = {
					i = {
						['<esc>'] = require('telescope.actions').close, -- instead of requiring double-esc
						['<c-k>'] = require('telescope.actions').move_selection_previous,
						['<c-j>'] = require('telescope.actions').move_selection_next,
					},
				},
			},
		},
	},
	{'folke/tokyonight.nvim', lazy=false, priority=1000}, -- colorschemes should be loaded first
	{'nvim-treesitter/nvim-treesitter', build=':TSUpdate'},
}
