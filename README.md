# iCloud NoSync: Exclude Files/Folders from iCloud Drive Sync on macOS

<img width="1280" height="640" alt="iCloudNoSync" src="https://github.com/user-attachments/assets/4890deab-cb62-448a-8901-224bbe50457d" />


This repository provides a Zsh function called `nosync` that allows you to easily mark files or folders (e.g., `node_modules`) as excluded from iCloud Drive syncing. It uses an undocumented but reliable `xattr` attribute (`com.apple.fileprovider.ignore#P`) to keep items local to your Mac, preventing unnecessary uploads and saving iCloud storage.

This is particularly useful for developers with projects in iCloud-synced folders like Documents or Desktop, where large temporary folders like `node_modules` can bloat your sync.

**Note**: This works on macOS Ventura, Sonoma, and Sequoia (as of July 2025). It's based on community-tested methods and is non-destructive—items can be unmarked if needed.

## Features
- Marks existing files or folders as non-syncing.
- Prompts to create missing items (as a file or directory) before marking.
- Supports multiple items at once (e.g., `nosync node_modules dist`).
- Built-in help: Run `nosync --help` for usage details.
- Safe and reversible: Use `xattr -d 'com.apple.fileprovider.ignore#P' item` to undo.

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

### If an Item Doesn't Exist
You'll be prompted:
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
To resume syncing:
```
xattr -d 'com.apple.fileprovider.ignore#P' node_modules
```

## The Code (`nosync.zsh`)
For reference, here's the full function:

```bash
# Mark file(s) or folder(s) to be excluded from iCloud sync, with prompt to create missing ones
nosync() {
    # Check for help flag
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: nosync [item1] [item2] ..."
        echo "Marks files or folders to be excluded from iCloud Drive sync."
        echo ""
        echo "Options:"
        echo "  --help, -h    Display this help message and exit."
        echo ""
        echo "Behavior:"
        echo "  - If an item exists, it is marked as non-syncing using xattr."
        echo "  - If an item does not exist, prompts to create it as a file (f), directory (d), or skip (s)."
        echo "  - Use 'f' or 'F' to create a file, 'd' or 'D' to create a directory, or 's' (or any other input) to skip."
        echo ""
        echo "Examples:"
        echo "  nosync node_modules          # Mark node_modules folder"
        echo "  nosync temp.cache           # Mark a file"
        echo "  nosync node_modules dist    # Mark multiple items"
        return 0
    fi

    # Process each item
    for item in "$@"; do
        if [ -e "$item" ]; then
            xattr -w 'com.apple.fileprovider.ignore#P' 1 "$item"
            echo "Marked $item as non-syncing for iCloud."
        else
            read -p "$item does not exist. Create it as a (f)ile, (d)irectory, or (s)kip? " answer
            case "$answer" in
                [Ff])
                    if touch "$item"; then
                        xattr -w 'com.apple.fileprovider.ignore#P' 1 "$item"
                        echo "Created and marked $item as non-syncing for iCloud."
                    else
                        echo "Error: Could not create file $item."
                        return 1
                    fi
                    ;;
                [Dd])
                    if mkdir -p "$item"; then
                        xattr -w 'com.apple.fileprovider.ignore#P' 1 "$item"
                        echo "Created and marked $item as non-syncing for iCloud."
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
    done
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
