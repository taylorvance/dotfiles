# Taylor's dotfiles

These are my dotfiles. There are many like them, but these are mine.

## Why?

I'm reinventing the wheel with this dotfile management solution. There are many tools that do what I need and much more. But that's just it. I want a tool that does exactly what I need and no more. I also relish the learning opportunity.

The [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles) approach is indeed elegant, but I have two gripes. You have to use an alias instead of using the git command (like `config diff`); and it doesn't allow you to store a README in the repo directory. I don't want to clutter my home with helper files that are specific to dotfile management.

[Dotbot](https://www.anishathalye.com/2014/08/03/managing-your-dotfiles/) was attractive--in fact, my solution is based on my cursory understanding of its philosophy--but I want to do things MY WAY dammit.

### My Way

The essence of my solution is this. Load up `dotfiles/home-away-from-HOME/` with all of your dotfiles, named and organized exactly as you want them to appear relative to your actual home directory (aka `~/`). Then `install` to create symlinks automatically.

## Getting Started

### Installation

Simply clone the repo and run the install script.

```
git clone https://github.com/taylorvance/dotfiles.git && ./dotfiles/install
```

This will create symlinks in your home directory for everything located in `dotfiles/home-away-from-HOME/` and configured in `dotfiles/config`. If there are any conflicts, your original files will be backed up in `dotfiles/backups/`.

Installation is [idempotent](https://en.wikipedia.org/wiki/Idempotence), which is a [word](https://github.com/anishathalye/dotfiles) [that](https://medium.com/@webprolific/getting-started-with-dotfiles-43c3602fd789) [dotfile](https://umanovskis.se/blog/post/dotfiles/) [articles](https://www.geekytidbits.com/dotfiles/) [love](https://unhexium.net/dotfiles/the-dotfile-drama/) [to](https://bananamafia.dev/post/dotfile-deployment/) [flaunt](https://www.evanjones.ca/dotfiles-personal-software-configuration.html).

### Adding new dotfiles

There are two steps needed to add a new dotfile.

1. Place the dotfile in `dotfiles/home-away-from-HOME/` exactly as it should appear relative to your own home directory. In other words, pretend `dotfiles/home-away-from-HOME/` is `~/`.

```
|-- dotfiles
    |-- home-away-from-HOME
        |-- .my-whole-directory
        |   |-- file1.cfg
        |   |-- file2.cfg
        |-- .vim
        |   |-- colors
        |       |-- mycolorscheme.vim
        |-- .vimrc
```

2. Add a line to `dotfiles/config`. You can link specific files or whole directories.

```
.my-whole-directory
.vim/colors/mycolorscheme.vim
.vimrc
```

## Usage

Use at your own risk.

```
|-- dotfiles
    |-- README.md
    |-- backups
    |   |-- 2020-01-08_04-08-15
    |       |-- .vimrc
    |-- config
    |-- home-away-from-HOME
    |   |-- .vim
    |   |   |-- colors
    |   |       |-- mycolorscheme.vim
    |   |-- .vimrc
    |-- install
```

#### Backups

When you run the install script, there may be files in your home directory that would be overwritten by symlinking. Any file with the same name as one configured to be symlinked will be moved to `dotfiles/backups/`, under a subdirectory named after the current date/time.

#### Config

`dotfiles/config` is a text file that tells the install script which files you want symlinked in your home directory. It works hand in hand with `dotfiles/home-away-from-HOME/`. You can link specific files or whole directories.

##### Specific files

Enter the file's relative path from `dotfiles/home-away-from-HOME/`. This will be the same path relative to `~/` after installation.

Example: `.vim/colors/mycolorscheme.vim` will link that file at `~/.vim/colors/mycolorscheme.vim` while leaving the rest of `~/.vim` intact.

##### Whole directories

Similar to specific files, enter the directory's relative path from `dotfiles/home-away-from-HOME/`. Trailing slash is unnecessary.

Example: `.my-whole-directory` will link that directory and all of its contents (recursively) at `~/.my-whole-directory/`.

NOTE: Any files that are in `~/.my-whole-directory/` but not in `dotfiles/home-away-from-HOME/.my-whole-directory/` will be moved to the backup folder during installation. If you wish to maintain untracked files in `~/.my-whole-directory/`, you must configure specific files rather than the whole directory. Instead of `.my-whole-directory`, enter `.my-whole-directory/file1.cfg` and `.my-whole-directory/file2.cfg`, etc.

### Forking

All of the content that is specific to my setup is in `dotfiles/home-away-from-HOME/` and `config`. If you want to start fresh, empty out both of those and insert your own files.
