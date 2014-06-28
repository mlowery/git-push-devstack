#!/usr/bin/env bash

# Some functions copied from DevStack itself

# Prints backtrace info
# filename:lineno:function
# backtrace level
backtrace() {
    local level=$1
    local deep=$((${#BASH_SOURCE[@]} - 1))
    echo "[Call Trace]"
    while [ $level -le $deep ]; do
        echo "${BASH_SOURCE[$deep]}:${BASH_LINENO[$deep-1]}:${FUNCNAME[$deep-1]}"
        deep=$((deep - 1))
    done
}

# Prints line number and "message" then exits
# die $LINENO "message"
die() {
    local exitcode=$?
    set +o xtrace
    local line=$1; shift
    if [[ $exitcode == 0 ]]; then
        exitcode=1
    fi
    backtrace 2
    err $line "$*"
    exit $exitcode
}

function_die() {
    local exitcode=$?
    set +o xtrace
    local line=$1; shift
    if [[ $exitcode == 0 ]]; then
        exitcode=1
    fi
    backtrace 2
    err $line "$*"
    return $exitcode
}

quiet_die() {
    local exitcode=$?
    local message="$1"
    echo "$message"
    exit $exitcode
}

# TODO prettier die methods

function_quiet_die() {
    local exitcode=$?
    local message="$1"
    echo "$message"
    return $exitcode
}

# Prints line number and "message" in error format
# err $LINENO "message"
err() {
    local exitcode=$?
    errXTRACE=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[ERROR] ${BASH_SOURCE[2]}:$1 $2"
    echo -e "********************\n${msg}\n********************" 1>&2;
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        echo $msg >> "${SCREEN_LOGDIR}/error.log"
    fi
    $errXTRACE
    return $exitcode
}

warn() {
    local msg="[WARNING] $1"
    echo -e "********************\n${msg}\n********************" 1>&2;
}

# Test if the named environment variable is set and not zero length
# is_set env-var
is_set() {
    local var=\$"$1"
    eval "[ -n \"$var\" ]" # For ex.: sh -c "[ -n \"$var\" ]" would be better, but several exercises depends on this
}

add_or_replace_in_file() {
    local search=$1
    local replace=$2
    local file=$3
    if [[ ! -f $file ]]; then
        touch $file
    fi
    if grep $search $file &> /dev/null; then
        sed -i "s@$search@$replace@" $file
    else
        echo -e "\n$replace" >> $file
    fi
}

# date for use in filenames
safe_date() {
    date +%Y_%m_%d__%H_%M_%S
}

git_cmd() {
    local repo_path=$1
    shift
    # env -i to eliminate GIT_DIR and GIT_WORK_TREE
    # see http://stackoverflow.com/questions/3542854/calling-git-pull-from-a-git-post-update-hook
    (cd $repo_path && env -i git "$@")
}

make_bare_repo_path() {
    local bare_repo_root_dir=$1
    local project=$2
    echo "$bare_repo_root_dir/$project.git"
}

log_info() {
    local msg=$1
    echo "INFO: $msg"
}


project_from_repo_url() {
    local git_repo_url=$1
    echo $(basename $git_repo_url .git)
}