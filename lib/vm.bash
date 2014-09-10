#!/usr/bin/env bash

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/common.bash

start_screen_window() {
    local name=$1
    # sends by up-arrow (recall last cmd) followed by Enter
    screen -S stack -p "$name" -X stuff $'\033[A'$'\015'
}

stop_screen_window() {
    local name=$1
    local binary=$2
    # sends Ctrl-C
    screen -S stack -p "$name" -X stuff $'\003'

    sleep 3

    # just make sure the binary is no longer running
    if [[ $(($(pgrep -fc $binary))) != 0 ]]; then
        function_die $LINENO "$binary did not stop"
    fi
}

backup_stash() {
    local repo_path=$1
    # quiet exits with 1 if there were differences and 0 means no differences
    if ! git_cmd $repo_path diff --quiet; then
        log_info "Stashing changes..."
        git_cmd $repo_path stash save -a "gpd-$(safe_date)" &> /dev/null
    fi
}

backup_tag() {
    local repo_path=$1
    # describe exits with 0 if a tag points to same commit as HEAD
    #git_cmd $repo_path describe --exact-match --tags HEAD &> /dev/null
    log_info "Tagging current commit..."
    git_cmd $repo_path tag "gpd-$(safe_date)" &> /dev/null

    #if ! git merge-base --is-ancestor HEAD $candidate_branch; then
    #    log_info "Tagging current commit..."
    #    git_cmd $repo_path tag "gpd-$(safe_date)" &> /dev/null
    #fi
}

post_receive() {
    local repo_path=$1
    backup_stash $repo_path
    backup_tag $repo_path
    log_info "Updating $repo_path..."
    git_cmd $repo_path fetch
    git_cmd $repo_path reset --hard origin/master
}

post_receive_begin() {
    set -e
    trap 'err ${LINENO} "post-receive hook failed"' EXIT
    read oldrev newrev refname
    log_info "Old revision: $oldrev"
    log_info "New revision: $newrev"
    log_info "Reference name: $refname"
    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source $dir/gpdrc
}

post_receive_end() {
    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    if [[ -f $dir/gpd_extra ]]; then
        source $dir/gpd_extra
        log_info "Running gpd_extra"
        gpd_extra
    fi
    trap - EXIT
}

post_receive_show_vars() {
    local file=$1
    local lines="$2"
    local formatted=$(post_receive_format_script_name $file)
    echo "${formatted^^} HOOK VARIABLES"
    echo "(Pass \"--hook-vars a=b\" to \"gpd setup-hook\" to set hook variable named \"a\" to value \"b\")"
    while read -r line; do
        printf "    $line\n"
    done <<< "$lines"
}

post_receive_check_vars() {
    (
    local file=$1
    local vars="$2"
    local errors=0

    eval "$vars"

    for var in "${@:3}"; do
        if ! is_set $var; then
            if [[ $errors == 0 ]]; then
                local formatted=$(post_receive_format_script_name $file)
                echo "${formatted^^} HOOK SETUP ERRORS"
                echo "(Use \"gpd describe-hook --project $formatted\" to see variables for this hook)"
            fi
            errors=$((errors+1))
            local num=$(printf %02d $errors)
            echo "    ${num}. $var is required"
        fi
    done
    return $errors
    )
    return $?
}

post_receive_format_script_name() {
    local script=$1
    echo $(basename $script .bash)
}

localrc_var_from_repo_url() {
    local git_repo_url=$1
    local project=$(project_from_repo_url $git_repo_url)
    local localrc_var=${project##python-}
    echo ${localrc_var^^}_REPO
}

setup_git_repo() {
    local git_repo_url=$1
    local branch="$2"
    local bare_repo_root_dir=$3
    local dest_repo_dir=$4
    local devstack_home_dir=${5:-""}
    local localrc_repo_var=${6:-""}
    local post_receive_vars=${7:-""}
    local project_name=${8:-"$(project_from_repo_url $git_repo_url)"}
    local run_hook=${9:-0}

    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    if [[ ! -d $bare_repo_root_dir ]]; then
        mkdir $bare_repo_root_dir
    fi

    dest_repo_dir_parent=$(dirname "$dest_repo_dir")
    if [[ ! -d "$dest_repo_dir_parent" ]]; then
        sudo mkdir -p "$dest_repo_dir_parent"
        sudo chown $(whoami) "$dest_repo_dir_parent"
    fi

    local post_receive_path="$dir/../post-receive/$project_name.bash"
    if [[ ! -x "$post_receive_path" ]]; then
        die $LINENO "$post_receive_path is missing or not executable"
    fi

    # check this hook's vars
    if ! "$post_receive_path" --check-vars "$post_receive_vars"; then
        return 1
    fi

    local bare_repo_dir=$bare_repo_root_dir/$project_name.git

    if [[ ! -d $bare_repo_dir ]]; then

        # first create a temp regular clone from start repo and start branch;
        # then create bare repo from that clone; its master will be the start
        # branch; any attempts to reset dest_repo_dir to origin/master will
        # go back to the right place

        tmp_clone=$(mktemp -d)
        git clone $git_repo_url $tmp_clone
        # if branch var contains a space, it is considered a command so just run it;
        # have to cd into dest_repo_dir since there may be multiple git commands
        # wrap in parens so as not to change working dir
        if [[ "$branch" =~ .*[[:space:]].* ]]; then
            (cd $tmp_clone && eval "$branch")
        else
            git_cmd $tmp_clone checkout $branch
        fi

        # clone and updates will always fetch master; set master to whatever the current commit is;
        # in this way, start branch (or whatever commit it created) becomes master
        git_cmd $tmp_clone update-ref refs/heads/master HEAD
        git clone --bare -l $tmp_clone $bare_repo_dir
        git clone $bare_repo_dir $dest_repo_dir

        ln -s $dir/../lib/common.bash $bare_repo_dir/hooks/common.bash
        ln -s $dir/../lib/vm.bash $bare_repo_dir/hooks/vm.bash
        ln -s $dir/../post-receive/$project_name.bash $bare_repo_dir/hooks/post-receive

        if [[ "$localrc_repo_var" ]]; then
            add_or_replace_in_file "^$localrc_repo_var=.*" "$localrc_repo_var=$bare_repo_dir" $devstack_home_dir/localrc
        fi
    else
        echo "WARN: $bare_repo_dir already exists; only writing gpdrc"
    fi
    # update vars every time
    add_or_replace_in_file "^dest_repo_dir=.*" "dest_repo_dir=$dest_repo_dir" $bare_repo_dir/hooks/gpdrc
    add_or_replace_in_file "^devstack_home_dir=.*" "devstack_home_dir=$devstack_home_dir"  $bare_repo_dir/hooks/gpdrc
    echo "$post_receive_vars" >> $bare_repo_dir/hooks/gpdrc

    if [[ $run_hook -eq 1 ]]; then
        (cd $bare_repo_dir/hooks && echo 1 2 3 | ./post-receive)
    fi
}