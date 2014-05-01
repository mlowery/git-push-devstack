#!/usr/bin/env bash

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/common.bash

setup_remote() {
    local project=$1
    local git_dir=$2
    local host=$3
    local user=$4
    local bare_repo_root_dir=$5
    local remote_name=$6

    local vm_repo_path=$(make_bare_repo_path $bare_repo_root_dir $project)
    check_ssh $user@$host $vm_repo_path

    if git_cmd "$git_dir" remote -v | grep "^$remote_name[[:blank:]]" > /dev/null; then
        function_die $LINENO "git remote with name \"$remote_name\" already exists."
    else
        git_cmd "$git_dir" remote add $remote_name $user@$host:$vm_repo_path
    fi
    git_cmd "$git_dir" config --local remote.$remote_name.push +HEAD:refs/heads/master
}

check_ssh() {
    local user_and_host=$1
    local path=$2
    # attempt ssh login with default cert; it must succeed
    set +e
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no $user_and_host -C "ls $path" &> /dev/null
    rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
        function_die $LINENO "ERROR: Sanity check failed: cannot ssh to $user_and_host."
    fi

}

make_remote_name() {
    local host=$1
    local short_host=
    if [[ $host =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        short_host=$host
    elif [[ $host =~ ^[A-Fa-f0-9:]+$ ]]; then
        short_host=$host
    else
        short_host=${host%%.*}
    fi
    local auto_remote_name_prefix=${GPD_AUTO_REMOTE_NAME_PREFIX:-gpd-}
    local auto_remote_name_suffix=${GPD_AUTO_REMOTE_NAME_SUFFIX:-}
    local auto_remote_name=$auto_remote_name_prefix$short_host$auto_remote_name_suffix
    #local remote_name=${9:-${auto_remote_name}}
    echo $auto_remote_name
}

project_from_git_work_dir() {
    local git_work_dir=$1
    local fetch_url=$(git_cmd $git_work_dir remote -v | grep "^origin[[:blank:]].*fetch" | cut -f 2 | cut -d " " -f 1)
    project_from_repo_url $fetch_url
}