#!/usr/bin/env bash

main() {
    post_receive_begin
    post_receive $dest_repo_dir
    post_receive_end
}

my_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
my_file="${BASH_SOURCE[0]}"
source $my_dir/../lib/vm.bash
case $1 in
    --check-vars)
    post_receive_check_vars $my_file "$2"
    shift
    ;;
    --show-vars)
    post_receive_show_vars $my_file ""
    ;;
    *)
    main
    ;;
esac

exit 0