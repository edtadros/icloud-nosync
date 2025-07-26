#!/usr/bin/env zsh

# Mark file(s) or folder(s) to be excluded from iCloud sync, with prompt to create missing ones
nosync() {
    local recursive=false
    local is_directory=false
    local is_file=false
    local unset=false
    local verbose=false
    local no_prune=false

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
        echo "  --directory, -d     With -r, target directories only (prunes subdirs after marking unless --no-prune)."
        echo "  --file, -f          With -r, target files only."
        echo "  --unset, -u         Remove the exclusion attribute to allow syncing again."
        echo "  --verbose, -v       Enable detailed output, including listing processed paths."
        echo "  --no-prune          With -r -d, disable prune to process subdirs of matched directories."
        echo ""
        echo "Behavior:"
        echo "  - Without --unset: Adds com.apple.fileprovider.ignore#P xattr to exclude from sync."
        echo "  - With --unset: Removes the attribute to resume sync."
        echo "  - If an item does not exist (non-recursive, without --unset), prompts to create it as a file (f), directory (d), or skip (s)."
        echo "  - Use 'f' or 'F' to create a file, 'd' or 'D' to create a directory, or 's' (or any other input) to skip."
        echo "  - In recursive mode, shows a spinner indicator; with --verbose, also lists paths."
        echo ""
        echo "Examples:"
        echo "  nosync node_modules          # Mark node_modules folder"
        echo "  nosync temp.cache            # Mark a file"
        echo "  nosync node_modules dist     # Mark multiple items"
        echo "  nosync -r -d node_modules    # Recursively mark all node_modules directories"
        echo "  nosync -r -f temp.cache      # Recursively mark all temp.cache files"
        echo "  nosync --unset node_modules  # Unmark node_modules folder"
        echo "  nosync -u -r -d node_modules # Recursively unmark all node_modules directories"
        echo "  nosync -v -r -d node_modules # Recursively mark with verbose output"
        echo "  nosync -r -d --no-prune node_modules # Recursively mark without pruning subdirs"
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
            --verbose|-v)
                verbose=true
                shift
                ;;
            --no-prune)
                no_prune=true
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
        if $no_prune && ! $is_directory; then
            echo "Error: --no-prune requires -d."
            return 1
        fi
    else
        if $is_directory || $is_file; then
            echo "Error: -d and -f require -r."
            return 1
        fi
        if $no_prune; then
            echo "Error: --no-prune requires -r -d."
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
        local prune_arg=""
        if $is_directory && ! $no_prune; then
            prune_arg="-prune"
        fi
        # Start spinner in background
        spinner &
        local spinner_pid=$!
        trap "kill $spinner_pid 2>/dev/null" EXIT

        for item in "$@"; do
            local found=false
            while IFS= read -r -d '' path; do
                if $verbose; then
                    echo "Processing $path"
                fi
                eval $(printf "$xattr_cmd" "$path" "$path")
                printf "$action_msg\n" "$path"
                found=true
            done < <(/usr/bin/find "${find_args[@]}" "$item" $prune_arg -print0)
            if ! $found; then
                echo "No matches found for $item recursively."
            fi
        done
        kill $spinner_pid 2>/dev/null
        trap - EXIT
        echo ""  # New line after spinner
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

# Spinner function for recursive mode
spinner() {
    local spin='-\|/'
    local i=0
    while true; do
        printf "\rProcessing... %c" "${spin:i++%${#spin}:1}"
        sleep 0.1
    done
}

nosync "$@"
