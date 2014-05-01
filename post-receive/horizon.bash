#!/usr/bin/env bash

copy_horizon_local_settings() {
    cp $dest_repo_dir/openstack_dashboard/local/local_settings.py.example $dest_repo_dir/openstack_dashboard/local/local_settings.py
}

main() {
    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source $dir/vm.bash
    post_receive_begin
    post_receive $dest_repo_dir
    # TODO source lib/horizon then init_horizon then restart_apache_server
    copy_horizon_local_settings
    sudo service apache2 restart
    post_receive_end
}

check_vars() {
    local my_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source $my_dir/../lib/vm.bash
    local vars=$1
    post_receive_check_vars "${BASH_SOURCE[0]}" "$vars"
}

show_vars() {
    local my_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source $my_dir/../lib/vm.bash
    var_desc=""
    post_receive_show_vars "${BASH_SOURCE[0]}" "$var_desc"
}

case $1 in
    --check-vars)
    check_vars "$2"
    shift
    ;;
    --show-vars)
    show_vars
    ;;
    *)
    main
    ;;
esac
