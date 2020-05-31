# Taylor's dotfiles [WIP]

These are my dotfiles. There are many like them, but these are mine.

## Why?

I'm reinventing the wheel with this dotfile management solution. There are many tools that do what I need and much more. But that's just it. I want a tool that does exactly what I need and no more. I also relish the learning opportunity. (Geez bash scripting is hard to learn. I had to Google every other line of code!)

The [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles) approach is indeed elegant, but I have two gripes. You have to use an alias instead of using the git command (like `config diff`); and it doesn't allow you to store a README in the repo directory. I don't want to clutter my home with helper files that are specific to dotfile management.

[Dotbot](https://www.anishathalye.com/2014/08/03/managing-your-dotfiles/) was attractive--in fact, my solution is based on my understanding of its philosophy--but I want to do things MY WAY dammit.

#### My Way

The essence of my solution is this. Load up `dotfiles/home-away-from-HOME/` with all of your dotfiles, named and organized exactly as you want them to appear relative to your actual home directory (aka `~/`). Then `install` to create symlinks automatically.

## Getting Started

### Installation

Simply clone the repo and run the install script.

```
git clone git@github.com:taylorvance/dotfiles.git && ./dotfiles/install
```

This will create symlinks in your home directory for everything located in `dotfiles/home-away-from-HOME/` and configured in `dotfiles/config`. If there are any conflicts, your original files will automatically be backed up in `dotfiles/backups/`.

### Adding new dotfiles

There are two steps needed to add a new dotfile.

1. Place the dotfile in `dotfiles/home-away-from-HOME/` exactly as it should appear relative to your own home directory. In other words, pretend `dotfiles/home-away-from-HOME/` is `~/`.

```
|-- dotfiles
    |-- home-away-from-HOME
        |-- .my-single-dotfile
        |-- .my-whole-directory
        |   |-- file1.cfg
        |   |-- file2.cfg
        |-- .vim
            |-- colors
                |-- mycolorscheme.vim
```

2. Add a line to `dotfiles/config`. You can link specific files or whole directories.

```
.my-single-dotfile
.my-whole-directory
.vim/colors/mycolorscheme.vim
```

## Project Structure

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

## Usage
