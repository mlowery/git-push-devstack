#!/bin/bash

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
    local cmd=$1
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $GUEST_USERNAME@$GUEST_IP "$cmd"
}

start_tr_guest() {
    do_in_guest "sudo service trove-guest start"
}

stop_tr_guest() {
    do_in_guest "sudo service trove-guest stop"
}

restart_tr_guest() {
    do_in_guest "sudo service trove-guest restart"
}

update_guest_code() {
    do_in_guest "sudo -u $GUEST_USERNAME rsync -e 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' -avz --exclude='.*' ${GUEST_USERNAME}@10.0.0.1:$dest_repo_dir/ /home/$GUEST_USERNAME/trove && sudo service trove-guest restart"
}

fix_guestagent_conf() {
    # trove-guestagent.conf is an odd-ball; it doesn't live in /etc/trove like
    # the other conf files since it is rsync'ed to the guest (and the rsync
    # only pulls /opt/stack/trove); furthermore, it's edited by DevStack (see
    # lib/trove) with NETWORK_GATEWAY, RABBIT_PASSWORD, and log settings; so
    # during a post-receive on trove, this needs to be run since the user's copy
    # will overwrite any edits by DevStack

    # execute in subshell
    (
    # copied from redstack.rc
    RABBIT_PASSWORD=f7999d1955c5014aa32c
    # copied from stack.sh
    ENABLE_DEBUG_LOG_LEVEL=True
    SYSLOG=False
    LOG_COLOR=True

    source $devstack_home_dir/functions
    source $devstack_home_dir/stackrc
    source $devstack_home_dir/lib/trove

    iniset $TROVE_LOCAL_CONF_DIR/trove-guestagent.conf.sample DEFAULT rabbit_password $RABBIT_PASSWORD
    sed -i "s/localhost/$NETWORK_GATEWAY/g" $TROVE_LOCAL_CONF_DIR/trove-guestagent.conf.sample
    setup_trove_logging $TROVE_LOCAL_CONF_DIR/trove-guestagent.conf.sample
    )
}


main() {
    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source $dir/vm.bash

    post_receive_begin
    post_receive $dest_repo_dir

    fix_guestagent_conf
    restart_tr_api
    restart_tr_tmgr
    restart_tr_cond
    echo "Pulling code onto guest ($GUEST_IP)..."
    update_guest_code
    post_receive_end
}

check_vars() {
    local me_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source $me_dir/../lib/vm.bash
    local vars=$1
    (
    eval "$vars"
    post_receive_check_vars devstack_home_dir
    )

    #TODO move to vm.bash to enforce consistency
    #TODO print name of post-receive file
    #TODO print format required for the arg
}

show_vars() {
    local me_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source $me_dir/../lib/vm.bash
    var_desc="guest_ip: IP of trove instance to which to push code updates
    devstack_home_dir: DevStack dir (used to call DevStack functions)"
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

