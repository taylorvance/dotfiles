# Taylor's dotfiles [WIP]

These are my dotfiles. There are many like them, but these are mine.

## Why?

I'm reinventing the wheel with this dotfile management solution. There are many tools that do what I need and much more. But that's just it. I want a tool that does exactly what I need and no more. I also relish the learning opportunity. (Geez bash scripting is hard to learn. I had to Google every other line of code!)

The [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles) approach is indeed elegant, but I have two main gripes: you have to set up an alias instead of using the git command, and it doesn't allow you to store a README in the repo directory. I don't want to clutter my home directory with helper files that are specific to dotfile management.

[Dotbot](https://www.anishathalye.com/2014/08/03/managing-your-dotfiles/) was attractive--in fact, my solution is based on my understanding of its philosophy. But I want to do things MY WAY damnit.

## Getting Started

### Installing

Simply clone the repo and run the install script.

```
git clone git@github.com:taylorvance/dotfiles.git && ./dotfiles/install
```

This will create symlinks in your home directory for everything located in `dotfiles/home/` and configured in `dotfiles/config`. If there are any conflicts, your original files will automatically be backed up in `dotfiles/backups/`.

### Adding new dotfiles

There are two steps needed to add a new dotfile.

1. Place the dotfile in `dotfiles/home/` exactly as it should appear relative to your own home directory.

```
# This will be symlinked at ~/.vimrc
dotfiles/home/.vimrc

# This will be symlinked at ~/.mysettings/another/file.cfg
dotfiles/home/.mysettings/another/file.cfg

# This will symlink the whole directory at ~/.somedirectory/
dotfiles/home/.somedirectory
```

2. Add a line to `dotfiles/config`. You can link specific files or whole directories. (Note, for directories, leave off the trailing slash.)

This is what your config file should look like for the example above.

```
.vimrc
.mysettings/another/file.cfg
.somedirectory
```

Note that `.somedirectory` links the whole directory recursively, whereas `.mysettings/another/file.cfg` links only `file.cfg` and not the whole `.mysettings` directory. This enables you to link certain files in `~/.mysettings/` but not all of them.
