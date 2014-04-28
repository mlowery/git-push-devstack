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
        git_cmd $repo_path stash save -u "git_push_devstack_$(safe_date)"
    fi
}

backup_tag() {
    local repo_path=$1
    # describe exits with 0 if a tag points to same commit as HEAD
    #git_cmd $repo_path describe --exact-match --tags HEAD &> /dev/null
    git_cmd $repo_path tag "git_push_devstack_$(safe_date)"
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
    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source $dir/gpdrc
}

post_receive_end() {
    trap - EXIT
}

project_from_repo_url() {
    local git_repo_url=$1
    # ## deletes from beginning using regex
    local last_path_segment=${git_repo_url##*/}
    # %% deletes from end using regex
    local project=${last_path_segment%%.*}
    echo $project
}

localrc_var_from_repo_url() {
    local git_repo_url=$1
    local project=$(project_from_repo_url $git_repo_url)
    local localrc_var=${project##python-}
    echo ${localrc_var}_REPO
}

setup_git_repo() {
    local git_repo_url=$1
    local branch=$2
    local bare_repo_root_dir=$3
    local dest_repo_dir=$4
    local devstack_home_dir=${5:-""}
    local localrc_repo_var=${6:-""}

    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    if [[ ! -d $bare_repo_root_dir ]]; then
        mkdir $bare_repo_root_dir
    fi

    local short_name=$(project_from_repo_url $git_repo_url)

    if [[ ! -x $dir/../post-receive/$short_name.bash ]]; then
        die $LINENO "$dir/../post-receive/$short_name.bash is missing or not executable"
    fi

    local bare_repo_dir=$bare_repo_root_dir/$short_name.git

    if [[ ! -d $bare_repo_dir ]]; then

        git clone --bare $git_repo_url $bare_repo_dir
        echo -e "\ndest_repo_dir=$dest_repo_dir" > $bare_repo_dir/hooks/gpdrc
        echo -e "\ndevstack_home_dir=$devstack_home_dir" >> $bare_repo_dir/hooks/gpdrc
        ln -s $dir/../lib/common.bash $bare_repo_dir/hooks/common.bash
        ln -s $dir/../lib/vm.bash $bare_repo_dir/hooks/vm.bash
        ln -s $dir/../post-receive/$short_name.bash $bare_repo_dir/hooks/post-receive
        git clone $bare_repo_dir $dest_repo_dir
        git --git-dir=$dest_repo_dir/.git --work-tree=$dest_repo_dir checkout $branch

        if [[ -n "$localrc_repo_var" ]]; then
            echo -e "\n$localrc_repo_var=$bare_repo_dir" >> $devstack_home_dir/localrc
        fi
    fi
}