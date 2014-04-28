source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/common.bash

prompt() {
    local prompt=$1
    local default=$2
    local final_prompt="$prompt "
    if [[ -n "$default" ]]; then
      final_prompt="$final_prompt(default: \"$default\") "
    fi
    read -p "$final_prompt> " TMP1
    if [[ -n "$TMP1" ]]; then
        echo "$TMP1"
    else
        echo $default
    fi
}

prompt_with_expansion() {
    local prompt=$1
    local default=$2
    local TMP1=`prompt "$prompt" "$default"`
    # expand tilde, etc if necessary
    eval echo $TMP1
}

git_config_local_prompt_and_set() {
    local key="$1"
    local default=`git config --get "$key"`
    local value=`prompt "Enter local git config value for \"$key\". Leave blank to let default value cascade." "$default"`
    if [[ -n "$value" ]]; then
        git config --local "$key" "$value"
    fi
}

setup_repo() {
    local project=$1

    git_config_local_prompt_and_set "user.name"
    git_config_local_prompt_and_set "user.email"
    # Specify your Gerrit (and launchpad.net) username.
    git_config_local_prompt_and_set "gitreview.username"
    git config --local pull.rebase true

    workflow=`prompt "Would you like to use the \"git push test\" workflow?" "y"`
    if [[ $workflow =~ ^[Yy]$ ]]; then
        vm=`prompt "Enter FQDN (preferred) or IP of RedStack VM." ""`
        # Setup remote test and refspec so you only need to run git push test
        # without any other args to copy changes to RedStack VM. All local branches
        # will be pushed to test/master. Furthermore, all pushes will overwrite
        # test/master even if not a fast-forward. This is OK as you will be the
        # only one pushing there. Always using masterkeeps the DevStack
        # configuration simple.
        local default_remote_name=test-${vm%-*}
        remote_name=`prompt "Enter git remote name for VM $vm." "$default_remote_name"`
        remote_add_cmd="git remote add $remote_name stack@$vm:/home/stack/gitrepos/$project.git"
        if git remote -v | grep "^$remote_name[[:blank:]]" > /dev/null; then
            overwrite=`prompt "Git remote with that name already exists. Overwrite?" "n"`
            if [[ $overwrite =~ ^[Yy]$ ]]; then
                git remote remove $remote_name
                $remote_add_cmd
            else
                echo "INFO: Remote $remote_name not overwritten!"
            fi
        else
            $remote_add_cmd
        fi
        git config --local remote.$remote_name.push +HEAD:refs/heads/master

        # attempt ssh login with default cert; it must succeed
        set +e
        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no stack@$vm -C "true" &> /dev/null
        rc=$?
        set -e
        if [[ $rc -ne 0 ]]; then
            die $LINENO "ERROR: Cannot ssh to stack@$vm. Check host and key."
        fi
    fi

    local gitreview_username=`git config --get "gitreview.username"`
    local gerrit_host=`cat .gitreview | grep host= | cut -d = -f 2 | tr -d ' '`
    local gerrit_port=`cat .gitreview | grep port= | cut -d = -f 2 | tr -d ' '`
    set +e
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p $gerrit_port $gitreview_username@$gerrit_host &> /dev/null
    rc=$?
    set -e
    # 127 returned on successful connect but when interactive shells are disabled
    if [[ $rc -ne 127 ]]; then
        die $LINENO "ERROR: Cannot ssh to $gitreview_username@$gerrit_host. Did you upload your key?"
    fi

    git review --setup
}

install_git_review() {
    if ! which git-review > /dev/null; then
        sudo pip install git-review
    fi
}

clone_and_setup() {
    local project=$1
    DO_PROJECT=`prompt "Do you want to setup $project repo (new clone or existing)?" "n"`
    if [[ $DO_PROJECT =~ ^[Yy]$ ]]; then
        SRC_DIR=`prompt_with_expansion "Enter existing $project clone (dir must contain .git) or dir into which to clone $project (dir will contain .git)." ""`
        if [[ ! -d "$SRC_DIR" ]]; then
            local default_repo_url="git://git.openstack.org/openstack/$project.git"
            repo_url=`prompt "Enter repo URL for project $project." "$default_repo_url"`
            git clone "$default_repo_url" "$SRC_DIR"
        else
            if [[ -d "$SRC_DIR/.git" ]]; then
                echo "INFO: Found existing clone."
            else
                die $LINENO "ERROR: \"$SRC_DIR\" is not a git repository."
            fi
        fi
        cd "$SRC_DIR"
        setup_repo "$project"
    fi
}

go() {
    local project=$1
    local git_dir=$2
    local host=$3
    local user=$4
    local bare_repo_root_dir=$5
    local remote_name=$6

    check_ssh $user@$host

    if git_cmd "$git_dir" remote -v | grep "^$remote_name[[:blank:]]" > /dev/null; then
        function_die $LINENO "git remote with name \"$remote_name\" already exists."
    else
        git_cmd "$git_dir" remote add $remote_name $user@$host:$(make_bare_repo_path $bare_repo_root_dir $project)
    fi
    git_cmd "$git_dir" config --local remote.$remote_name.push +HEAD:refs/heads/master
}

check_ssh() {
    local user_and_host=$1
    # attempt ssh login with default cert; it must succeed
    set +e
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no $user_and_host -C "true" &> /dev/null
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
    local auto_remote_name=$remote_prefix$short_host$remote_suffix
    #local remote_name=${9:-${auto_remote_name}}
    echo $auto_remote_name
}
