https://lazy.folke.io/installation

Requires nvim 0.11+ (vim.lsp.config, nvim-treesitter main branch).

~/.config/nvim
├── README.md
├── init.vim           <-- my nvim init (re:"vimrc")
├── lazy-lock.json     <-- pinned plugin versions (lazy.nvim writes through the symlink)
└── lua
    ├── config
    │   └── lazy.lua   <-- bootstraps lazy.nvim plugin manager (called by init.vim)
    └── plugins
        ├── init.lua   <-- loads plugins
        └── ...        <-- plugins can be configured/extended in their own .lua files (e.g. snacks.lua)
