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

main