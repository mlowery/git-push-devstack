#!/usr/bin/env bash

main() {
    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source $dir/vm.bash
    post_receive_begin
    post_receive $dest_repo_dir
    post_receive_end
}

main