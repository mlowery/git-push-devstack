#!/usr/bin/env bash

copy_horizon_local_settings() {
    cp $dest_repo_dir/openstack_dashboard/local/local_settings.py.example $dest_repo_dir/openstack_dashboard/local/local_settings.py
}

main() {
    post_receive_begin
    post_receive $dest_repo_dir
    # TODO source lib/horizon then init_horizon then restart_apache_server
    copy_horizon_local_settings
    sudo service apache2 restart
    post_receive_end
}

my_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
my_file="${BASH_SOURCE[0]}"
if [[ -f $my_dir/vm.bash ]]; then
    source $my_dir/vm.bash
else
    source $my_dir/../lib/vm.bash
fi

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