# iCloud NoSync: Exclude Files/Folders from iCloud Drive Sync on macOS

<img width="1280" height="640" alt="iCloudNoSync" src="https://github.com/user-attachments/assets/4890deab-cb62-448a-8901-224bbe50457d" />

This repository provides a Zsh function called `nosync` that allows you to easily mark files or folders (e.g., `node_modules`) as excluded from iCloud Drive syncing. It uses an undocumented but reliable `xattr` attribute (`com.apple.fileprovider.ignore#P`) to keep items local to your Mac, preventing unnecessary uploads and saving iCloud storage.

This is particularly useful for developers with projects in iCloud-synced folders like Documents or Desktop, where large temporary folders like `node_modules` can bloat your sync.

**Note**: This works on macOS Ventura, Sonoma, and Sequoia (as of July 2025). It's based on community-tested methods and is non-destructive—items can be unmarked if needed. The xattr method may not work reliably on macOS Sequoia (15.x) and later due to potential changes in iCloud behavior. Consider alternatives like renaming with `.nosync` for newer macOS versions.

## Features
- Marks existing files or folders as non-syncing by adding the com.apple.fileprovider.ignore#P xattr attribute.
- Unmarks items (removes the attribute) to resume syncing with --unset.
- Prompts to create missing items (as a file or directory) before marking in non-recursive mode.
- Supports multiple items at once (e.g., `nosync node_modules dist`).
- Recursive search (--recursive or -r) to mark/unmark all matching items, with --directory (-d) for directories (prunes subdirs after marking) or --file (-f) for files.
- Built-in help: Run `nosync --help` for usage details.
- Safe and reversible: Use --unset to remove the attribute.
- Uses full paths for commands to avoid PATH issues.

## Installation
1. **Clone the Repository**:
   ```
   git clone https://github.com/yourusername/icloud-nosync.git
   cd icloud-nosync
   ```

2. **Add to Your Shell**:
   - Copy the contents of `nosync.zsh` into your `~/.zshrc` file:
     ```
     nano ~/.zshrc
     # Paste the function at the bottom
     ```
   - Or source the file directly in `~/.zshrc`:
     ```
     source ~/path/to/icloud-nosync/nosync.zsh
     ```
   - Reload your shell:
     ```
     source ~/.zshrc
     ```

If you're using Bash (not default on macOS), minor tweaks may be needed for compatibility (e.g., change `[[ ]]` to `[ ]`).

## Usage
Run the function in your terminal from the directory containing the items.

### Basic Examples
- Mark a folder:
  ```
  nosync node_modules
  ```
- Mark a file:
  ```
  nosync temp.cache
  ```
- Mark multiple items:
  ```
  nosync node_modules dist build.log
  ```
- Unmark a folder to resume syncing:
  ```
  nosync --unset node_modules
  ```
- Recursively mark all node_modules directories:
  ```
  nosync -r -d node_modules
  ```
- Recursively unmark all temp.cache files:
  ```
  nosync -u -r -f temp.cache
  ```

### If an Item Doesn't Exist (Non-Recursive Mode Only)
You'll be prompted (only when marking, not unsetting):
```
temp.cache does not exist. Create it as a (f)ile, (d)irectory, or (s)kip?
```
- `f` or `F`: Create as an empty file and mark it.
- `d` or `D`: Create as a directory and mark it.
- `s` or anything else: Skip without creating.

### Help
```
nosync --help
```
Or `nosync -h` for details on syntax and behavior.

### Verify
In Finder, marked items should show a cloud icon with a slash (local-only). Check the attribute:
```
xattr -l node_modules
```
Output: `com.apple.fileprovider.ignore#P: 1`

### Undo
To resume syncing, use the --unset option:
```
nosync --unset node_modules
```
Or manually:
```
xattr -d 'com.apple.fileprovider.ignore#P' node_modules
```

## The Code (`nosync.zsh`)
For reference, here's the full function:

```bash
# Mark file(s) or folder(s) to be excluded from iCloud sync, with prompt to create missing ones
nosync() {
    local recursive=false
    local is_directory=false
    local is_file=false
    local unset=false

    # Check for help flag first
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: nosync [options] [item1] [item2] ..."
        echo "Marks files or folders to be excluded from iCloud Drive sync."
        echo ""
        echo "Options:"
        echo "  --help, -h          Display this help message and exit."
        echo "  --recursive, -r     Recursively search from the current directory for items"
        echo "                      matching the given names (files or folders) and mark/unmark them."
        echo "                      No creation prompt in this mode. Requires -d or -f."
        echo "  --directory, -d     With -r, target directories only (prunes subdirs after marking)."
        echo "  --file, -f          With -r, target files only."
        echo "  --unset, -u         Remove the exclusion attribute to allow syncing again."
        echo ""
        echo "Behavior:"
        echo "  - Without --unset: Adds com.apple.fileprovider.ignore#P xattr to exclude from sync."
        echo "  - With --unset: Removes the attribute to resume sync."
        echo "  - If an item does not exist (non-recursive, without --unset), prompts to create it as a file (f), directory (d), or skip (s)."
        echo "  - Use 'f' or 'F' to create a file, 'd' or 'D' to create a directory, or 's' (or any other input) to skip."
        echo ""
        echo "Examples:"
        echo "  nosync node_modules          # Mark node_modules folder"
        echo "  nosync temp.cache            # Mark a file"
        echo "  nosync node_modules dist     # Mark multiple items"
        echo "  nosync -r -d node_modules    # Recursively mark all node_modules directories"
        echo "  nosync -r -f temp.cache      # Recursively mark all temp.cache files"
        echo "  nosync --unset node_modules  # Unmark node_modules folder"
        echo "  nosync -u -r -d node_modules # Recursively unmark all node_modules directories"
        return 0
    fi

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --recursive|-r)
                recursive=true
                shift
                ;;
            --directory|-d)
                is_directory=true
                shift
                ;;
            --file|-f)
                is_file=true
                shift
                ;;
            --unset|-u)
                unset=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ $# -eq 0 ]]; then
        echo "Error: No items specified. Use --help for usage."
        return 1
    fi

    if $recursive; then
        if ! $is_directory && ! $is_file; then
            echo "Error: -r requires -d or -f."
            return 1
        fi
        if $is_directory && $is_file; then
            echo "Error: Cannot use -d and -f together."
            return 1
        fi
    else
        if $is_directory || $is_file; then
            echo "Error: -d and -f require -r."
            return 1
        fi
    fi

    local xattr_cmd
    local action_msg
    local action_present="Marked"
    local action_past="Marked"
    if $unset; then
        xattr_cmd="/usr/bin/xattr -d 'com.apple.fileprovider.ignore#P' \"%s\" || echo \"Failed to unmark %s (error: \$?)\""
        action_msg="Unmarked %s for iCloud sync."
        action_present="Unmarking"
        action_past="Unmarked"
    else
        xattr_cmd="/usr/bin/xattr -w 'com.apple.fileprovider.ignore#P' 1 \"%s\" || echo \"Failed to mark %s (error: \$?)\""
        action_msg="Marked %s as non-syncing for iCloud."
    fi

    if $recursive; then
        local -a find_args
        find_args=( . )
        if $is_directory; then
            find_args+=( -type d -name )
        elif $is_file; then
            find_args+=( -type f -name )
        fi
        for item in "$@"; do
            local found=false
            while IFS= read -r -d '' path; do
                eval $(printf "$xattr_cmd" "$path" "$path")
                printf "$action_msg\n" "$path"
                found=true
            done < <(/usr/bin/find "${find_args[@]}" "$item" -prune -print0)
            if ! $found; then
                echo "No matches found for $item recursively."
            fi
        done
    else
        # Non-recursive mode: process each item directly
        for item in "$@"; do
            if [ -e "$item" ]; then
                eval $(printf "$xattr_cmd" "$item" "$item")
                printf "$action_msg\n" "$item"
            else
                if $unset; then
                    echo "Skipped $item: Does not exist (nothing to unmark)."
                else
                    read -p "$item does not exist. Create it as a (f)ile, (d)irectory, or (s)kip? " answer
                    case "$answer" in
                        [Ff])
                            if /bin/touch "$item"; then
                                eval $(printf "$xattr_cmd" "$item" "$item")
                                printf "Created and $action_past %s as non-syncing for iCloud.\n" "$item"
                            else
                                echo "Error: Could not create file $item."
                                return 1
                            fi
                            ;;
                        [Dd])
                            if /bin/mkdir -p "$item"; then
                                eval $(printf "$xattr_cmd" "$item" "$item")
                                printf "Created and $action_past %s as non-syncing for iCloud.\n" "$item"
                            else
                                echo "Error: Could not create directory $item."
                                return 1
                            fi
                            ;;
                        [Ss]*|*)
                            echo "Skipped $item (not created)."
                            ;;
                    esac
                fi
            fi
        done
    fi
}
```

## Limitations and Alternatives
- **macOS-Only**: Relies on Apple's `xattr` and iCloud Drive.
- **Undocumented**: The attribute could change in future macOS updates—test after upgrades.
- **Alternatives**: Rename items with `.nosync` (e.g., `node_modules.nosync`) and symlink back, or move projects out of iCloud folders.
- **Not Synced**: Marked items won't appear on other devices; regenerate as needed (e.g., `npm install`).

## Contributing
Feel free to fork and submit pull requests for improvements, like Bash support or automation scripts.

## License
MIT License (or your choice—update accordingly).

If you encounter issues, open an issue on this repo!
