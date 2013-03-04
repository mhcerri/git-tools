#!/bin/bash

# Default options
VERBOSE=0
EMAIL=0
SORT_FIELD=1

# Print usage and arguments
usage() {
    echo "usage: $(basename $0) [<options>] [-- <git-log-arguments>]"
    echo
    echo -e "    -h, --help\t\t\tshow this message"
    echo -e "    -v, --verbose\t\tprint additional info"
    echo -e "    -s, --sort-by <field>\tsort results based on a field. The valid"
    echo -e "    \t\t\t\tfields are: total, inserted, deleted, commits and author"
    echo -e "    --use-email\t\t\tuse email as part of author string"
    echo 
}

fatal() {
    echo "fatal: $@" >&2
    exit 1
}
 
# Parse arguments
while [ "$#" -gt 0 ]; do
    case $1 in
    -h|--help)
        usage >&2
        exit 1
        ;;
    -v|--verbose)
        VERBOSE=1
        ;;
    -s|--sort-by)
        if [ -z "$2" ]; then
            fatal "missing field for option $1"
        fi
        case $2 in
        total) SORT_FIELD=1;;
        inserted) SORT_FIELD=2;;
        deleted) SORT_FIELD=3;;
        commits) SORT_FIELD=4;;
        author) SORT_FIELD=5;;
        *) fatal "invalid field: $2";;
        esac
        shift
        ;;
    --use-email)
        EMAIL=1
        ;;
    --)
        shift
        break
        ;;
    *)
        fatal "unrecognized argument: $1"
        exit 1
    esac
    shift
done

# print total, include and removed by author
git_stats() {
    if [ "$VERBOSE" -ne 0 ]; then
        echo "running: git log --numstat $@" >&2
    fi
    git log --numstat $@ |
    awk -v email="$EMAIL" '
        /^Author:/ {
            author = substr($0, length($1) + length(FS) + 1)
            if (!email)
                sub(/ <.*>/, "", author)
            commits[author] += 1
        }
        /^[0-9]+[\t ]+[0-9]+/ {
            inserted[author] += $1
            deleted[author] += $2
            total[author] += $1 + $2
        }
        END {
            for (author in total)
                printf("%d\t%d\t%d\t%d\t%s\n", total[author], inserted[author],
                        deleted[author], commits[author], author)
        }
    '
}

# Main
(
    # Add header
    echo -e "Total\tInserted\tDeleted\tCommits\tAuthor"
    # Sort stats
    git_stats $@ | sort -n -r -k "$SORT_FIELD"
) |
# Format in a table
column -t -s "$(echo -ne \\t)"
