#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
BACKUPDIR=$BASEDIR/backups/"$(date +%Y-%m-%d_%H%M%S)"
DESTINATIONDIR=$HOME

# Create a backup subdirectory for any conflicting files.
if [ -d "$BACKUPDIR" ]; then
	echo "Backup directory ${BACKUPDIR} already exists. Please wait literally one second and try again."
	return
fi
mkdir -p $BACKUPDIR

# Set up symlinks for all files/folders in the dotfiles home folder.
files="`ls -a $BASEDIR/home`"

for filename in $files; do
	# Ignore . and ..
	if [ "$filename" = "." ] || [ "$filename" = ".." ]; then
		continue
	fi

	oldfile=$DESTINATIONDIR/$filename
	newfile=$BASEDIR/home/$filename

	# If the file is already correctly symlinked, skip.
	if [ "$(readlink $oldfile)" = "$newfile" ]; then
		echo "Symlink already exists for $oldfile"
		continue
	fi

	# If a file with this name exists, move it to the backup folder to avoid overwriting.
	if [ -e $oldfile ]; then
		echo "Moving existing $filename to backup folder"
		mv $oldfile $BACKUPDIR
	fi

	echo "Creating symlink for $filename"
	ln -Ffs $newfile $DESTINATIONDIR
done

# Remove the new backup dir if nothing was added to it.
rmdir $BACKUPDIR >/dev/null 2>&1
