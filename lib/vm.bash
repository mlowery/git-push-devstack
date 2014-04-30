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
        echo "Stashing changes..."
        git_cmd $repo_path stash save -u "gpd-$(safe_date)"
    fi
}

backup_tag() {
    local repo_path=$1
    # describe exits with 0 if a tag points to same commit as HEAD
    #git_cmd $repo_path describe --exact-match --tags HEAD &> /dev/null
    git_cmd $repo_path tag "gpd-$(safe_date)"
}

post_receive() {
    local repo_path=$1
    backup_stash $repo_path
    backup_tag $repo_path
    echo "Updating $repo_path..."
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
    trap - EXIT
}

post_receive_show_vars() {
    local file=$1
    local lines="$2"
    echo "$(post_receive_format_script_name $file) VARIABLES"
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

    for var in "$@"; do
        if ! is_set $var; then
            if [[ $errors == 0 ]]; then
                echo "$(post_receive_format_script_name $file) SETUP ERRORS"
                echo "(Use gpd vm-hook-info to see variables for this hook)"
            fi
            errors=$((errors+1))
            echo "ERROR: $var is missing or invalid"
        fi
    done
    return $errors
    )
}

post_receive_format_script_name() {
    local script=$1
    echo $(basename $script .bash)
}

project_from_repo_url() {
    local git_repo_url=$1
    # ## deletes from beginning using regex
    local last_path_segment=${git_repo_url##*/}
    # %% deletes from end using regex
    local project=${last_path_segment%%.*}
    # TODO: basename $git_repo_url .git
    echo $project
}

localrc_var_from_repo_url() {
    local git_repo_url=$1
    local project=$(project_from_repo_url $git_repo_url)
    local localrc_var=${project##python-}
    echo ${localrc_var^^}_REPO
}

setup_git_repo() {
    local git_repo_url=$1
    local branch=$2
    local bare_repo_root_dir=$3
    local dest_repo_dir=$4
    local devstack_home_dir=${5:-""}
    local localrc_repo_var=${6:-""}
    local post_receive_vars=${7:-""}

    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    if [[ ! -d $bare_repo_root_dir ]]; then
        mkdir $bare_repo_root_dir
    fi

    dest_repo_dir_parent=$(dirname "$dest_repo_dir")
    if [[ ! -d "$dest_repo_dir_parent" ]]; then
        sudo mkdir -p "$dest_repo_dir_parent"
        sudo chown $(whoami) "$dest_repo_dir_parent"
    fi

    local short_name=$(project_from_repo_url $git_repo_url)

    local post_receive_path="$dir/../post-receive/$short_name.bash"
    if [[ ! -x "$post_receive_path" ]]; then
        die $LINENO "$post_receive_path is missing or not executable"
    fi

    # check this hook's vars
    #if ! "$post_receive_path" --check-vars "$post_receive_vars"; then
    #    return 1
    #fi
    #TODO come back to check-vars code

    local bare_repo_dir=$bare_repo_root_dir/$short_name.git

    #TODO think about idempotency
    if [[ ! -d $bare_repo_dir ]]; then

        git clone --bare $git_repo_url $bare_repo_dir

        ln -s $dir/../lib/common.bash $bare_repo_dir/hooks/common.bash
        ln -s $dir/../lib/vm.bash $bare_repo_dir/hooks/vm.bash
        ln -s $dir/../post-receive/$short_name.bash $bare_repo_dir/hooks/post-receive
        git clone $bare_repo_dir $dest_repo_dir
        git_cmd $dest_repo_dir checkout $branch
        #TODO clone or pull

        if [[ -n "$localrc_repo_var" ]]; then
            add_or_replace_in_file "^$localrc_repo_var=.*" "$localrc_repo_var=$bare_repo_dir" ~/devstack/localrc
        fi
    else
        echo "WARN: $bare_repo_dir already exists"
    fi
    # update vars every time
    add_or_replace_in_file "^dest_repo_dir=.*" "dest_repo_dir=$dest_repo_dir" $bare_repo_dir/hooks/gpdrc
    add_or_replace_in_file "^devstack_home_dir=.*" "devstack_home_dir=$devstack_home_dir"  $bare_repo_dir/hooks/gpdrc
    #echo "$post_receive_vars" >> $bare_repo_dir/hooks/gpdrc

}