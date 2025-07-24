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
