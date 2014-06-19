#!/usr/bin/env bash

stop_tr_api() {
    stop_screen_window tr-api bin/trove-api
}

stop_tr_tmgr() {
    stop_screen_window tr-tmgr bin/trove-taskmanager
}

stop_tr_cond() {
    stop_screen_window tr-cond bin/trove-conductor
}

start_tr_api() {
    start_screen_window tr-api bin/trove-api
}

start_tr_tmgr() {
    start_screen_window tr-tmgr bin/trove-taskmanager
}

start_tr_cond() {
    start_screen_window tr-cond bin/trove-conductor
}

restart_tr_api() {
    stop_tr_api
    start_tr_api
}

restart_tr_tmgr() {
    stop_tr_tmgr
    start_tr_tmgr
}

restart_tr_cond() {
    stop_tr_cond
    start_tr_cond
}

do_in_guest() {
    local guest_ip=$1
    local cmd=$2
    ssh -o ConnectTimeout=3 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $(whoami)@$guest_ip "$cmd"
}

update_guest_code() {
    local guest_ip=$1
    echo "Pulling code onto guest ($guest_ip)..."
    local guest_username=$(whoami)
    do_in_guest $guest_ip "sudo -u $guest_username rsync -e 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' -avz --exclude='.*' ${guest_username}@10.0.0.1:$dest_repo_dir/ /home/$guest_username/trove && sudo service trove-guest restart"
}

main() {
    post_receive_begin
    post_receive $dest_repo_dir

    restart_tr_api
    restart_tr_tmgr
    restart_tr_cond
    update_guest_code $guest_ip

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
    post_receive_check_vars $my_file "$2" guest_ip
    exit $?
    ;;
    --show-vars)
    post_receive_show_vars $my_file "guest_ip: IP of trove instance to which to push code updates"
    ;;
    *)
    main
    ;;
esac

exit 0