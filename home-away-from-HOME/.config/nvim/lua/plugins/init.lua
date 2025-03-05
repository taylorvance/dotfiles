return {
	'github/copilot.vim',
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
						on_click = function()
							-- toggle diagnostics
							vim.diagnostic.enable(not vim.diagnostic.is_enabled())
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
			-- Setup Mason (LSP installer)
			require('mason').setup()
			-- Setup Mason-LSPConfig bridge
			require('mason-lspconfig').setup({
				--                   python    php            c#          vim     lua
				ensure_installed = {'pyright','intelephense','omnisharp','vimls','lua_ls'},
				automatic_installation = true,
			})
			-- Configure LSP servers automatically when they are installed
			local lspconfig = require('lspconfig')
			require('mason-lspconfig').setup_handlers({
				function(server_name)
					lspconfig[server_name].setup({})
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
