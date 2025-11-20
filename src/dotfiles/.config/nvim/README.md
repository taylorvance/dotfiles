https://lazy.folke.io/installation

~/.config/nvim
├── README.md
├── init.vim           <-- my nvim init (re:"vimrc")
└── lua
    ├── config
    │   └── lazy.lua   <-- bootstraps lazy.nvim plugin manager (called by init.vim)
    └── plugins
        ├── init.lua   <-- loads plugins
        └── ...        <-- plugins can be configured/extended in their own .lua files (e.g. telescope.lua)
