# Mark file(s) or folder(s) to be excluded from iCloud sync, with prompt to create missing ones
nosync() {
    local recursive=false

    # Check for help flag first
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: nosync [options] [item1] [item2] ..."
        echo "Marks files or folders to be excluded from iCloud Drive sync."
        echo ""
        echo "Options:"
        echo "  --help, -h          Display this help message and exit."
        echo "  --recursive, -r     Recursively search from the current directory for items"
        echo "                      matching the given names (files or folders) and mark them."
        echo "                      No creation prompt in this mode."
        echo ""
        echo "Behavior:"
        echo "  - If an item exists, it is marked as non-syncing using xattr."
        echo "  - If an item does not exist (non-recursive), prompts to create it as a file (f), directory (d), or skip (s)."
        echo "  - Use 'f' or 'F' to create a file, 'd' or 'D' to create a directory, or 's' (or any other input) to skip."
        echo ""
        echo "Examples:"
        echo "  nosync node_modules          # Mark node_modules folder"
        echo "  nosync temp.cache            # Mark a file"
        echo "  nosync node_modules dist     # Mark multiple items"
        echo "  nosync -r node_modules       # Recursively mark all node_modules folders"
        return 0
    fi

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --recursive|-r)
                recursive=true
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
        for item in "$@"; do
            local found=false
            while IFS= read -r -d '' path; do
                /usr/bin/xattr -w 'com.apple.fileprovider.ignore#P' 1 "$path" || echo "Failed to mark $path (error: $?)"
                echo "Marked $path as non-syncing for iCloud."
                found=true
            done < <(find . -name "$item" -print0)
            if ! $found; then
                echo "No matches found for $item recursively."
            fi
        done
    else
        # Non-recursive mode: process each item directly
        for item in "$@"; do
            if [ -e "$item" ]; then
                /usr/bin/xattr -w 'com.apple.fileprovider.ignore#P' 1 "$item" || echo "Failed to mark $item (error: $?)"
                echo "Marked $item as non-syncing for iCloud."
            else
                read -p "$item does not exist. Create it as a (f)ile, (d)irectory, or (s)kip? " answer
                case "$answer" in
                    [Ff])
                        if touch "$item"; then
                            /usr/bin/xattr -w 'com.apple.fileprovider.ignore#P' 1 "$item" || echo "Failed to mark $item (error: $?)"
                            echo "Created and marked $item as non-syncing for iCloud."
                        else
                            echo "Error: Could not create file $item."
                            return 1
                        fi
                        ;;
                    [Dd])
                        if mkdir -p "$item"; then
                            /usr/bin/xattr -w 'com.apple.fileprovider.ignore#P' 1 "$item" || echo "Failed to mark $item (error: $?)"
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
    fi
}
