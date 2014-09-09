# git-push-devstack

## Introduction

git-push-devstack (gpd) is a development workflow for OpenStack projects.
gpd was built for OpenStack developers who want to code locally and automate
the copy-to-DevStack-VM-and-restart-services sequence.

Where [Vagrant](http://www.vagrantup.com/) might be used for sharing files with
local DevStack VMs, gpd automates the sharing of files with remote DevStack VMs.

With gpd, `git
push` serves as a mechanism for copying changes from your laptop (or wherever
you code) to your [DevStack](http://devstack.org/) VM. `git push` also serves as a mechanism to trigger
any restarts or other actions upon uploading new code.

## Requirements

gpd requires only bash and git.

## Installation

gpd must be installed on the DevStack VM and wherever you code (simply called
"laptop" for the rest of this document). Installation is just cloning this repository
and possibly adding the `bin` directory to your `PATH`.

## Setup

### Step 1

Run `gpd setup-hook` on your DevStack VM before running `stack.sh`:

```bash
# clone DevStack
$ git clone https://github.com/openstack-dev/devstack.git ~/devstack
# clone gpd
$ git clone https://github.com/mlowery/git-push-devstack.git
# setup vm to receive pushes
$ cd git-push-devstack/bin && ./gpd setup-hook --start-repo https://github.com/openstack/horizon.git
# run DevStack's stack.sh
$ cd ~/devstack && ./stack.sh
```

### Step 2

Run `gpd setup-remote` on your laptop:

```bash
# clone OpenStack project (e.g. horizon) if not already cloned
$ git clone https://github.com/openstack/horizon.git ~/horizon
# setup laptop to send pushes
$ gpd setup-remote --git-work-dir ~/horizon --server horizontest.example.com
$ cd ~/horizon
# make some changes here (not shown)
# commit
$ git commit -a
# push your changes to the DevStack VM
$ git push gpd-horizontest
```

Check out Advanced Setup below for more control.

## Using

The entire goal of gpd is to handle the copying of your local changes to a
DevStack VM. After setup on the DevStack VM and your laptop, just do the
following:

```bash
git commit -a
git push gpd-horizontest
```

While there is a commit necessary per push, you get built-in push history by
doing so (use interactive rebase to squash commits before submitting to
Gerrit). And if you dislike commit proliferation, use `--amend` every time
instead.

## How It Works

`gpd setup-hook` sets up a git [bare repository](http://git-scm.com/book/en/Git-on-the-Server-Getting-Git-on-a-Server)
with a [post-receive](http://git-scm.com/book/en/Customizing-Git-Git-Hooks)
hook. The bare repository accepts whatever you push from your laptop, then
copies those changes to `/opt/stack/<project>` (or wherever DevStack's `$DEST` is).
Additionally, services are restarted during the hook run--in general, the hook completes whatever is
necessary for your changes to fully take effect (e.g. `service apache2 restart`).

`gpd setup-remote` sets up a git [remote](http://git-scm.com/book/en/Git-Basics-Working-with-Remotes) (like `origin`).
Pushes to the bare repository
are forced (i.e. non-fast-forward updates are allowed)
which allows you to jump between unrelated commits. Finally, just to be safe, all
changes in the `/opt/stack/<project>` directory are stashed or tagged to
prevent any local changes you may have made while hacking (which you should avoid
if possible).

## What OpenStack Projects Are Supported

There are `post-receive` hooks for the following projects:
* horizon
* trove
* trove-integration
* python-troveclient

Adding more `post-receive` hooks is as simple as adding a file to the
`post-receive` directory. Use `horizon.bash` as a starter template.

## Best Practices

* Automate `gpd setup-hook` using [Puppet](http://puppetlabs.com/), [Fabric](http://www.fabfile.org/), [User Data](http://docs.openstack.org/user-guide/content/user-data.html), or ssh.
* Take advantage of `GPD_*` environment variables to eliminate repeating
rarely-changing values. Example: If your DevStack VM user is always `ubuntu`,
set `GPD_REMOTE_USER` to `ubuntu`.

## Advanced Setup

This section describes some of the options that can give you more control over
gpd's behavior or eliminate the need to repeatedly enter rarely-changing options.

### gpd setup-repo

```bash
$ gpd setup-hook --help

NAME
    gpd setup-hook - setup bare repo and hook on DevStack VM

USAGE
    gpd setup-hook --start-repo <start-repo>
                   [--dest-repo-dir <dest-repo-dir>]
                   [--devstack-home-dir <devstack-home-dir>]
                   [--localrc-repo-dir <localrc-repo-var>]
                   [--start-branch <start-branch>]
                   [--bare-repo-root-dir <bare-repo-root-dir>]
                   [--hook-vars <hook-vars>]
                   [--project <project-name>]
                   [--run-hook]
                   [--verbose]
                   [--help]

DESCRIPTION
    Sets up bare repo in $bare-repo-root-dir and installs post-receive hook to
copy files on git push to $dest-repo-dir. Affected processes are restarted
during the hook run.

    The current user must have write access to the entire $bare-repo-root-dir
tree.

    In order to push to the bare repo, you must setup key-based SSH login for
the user running this script.

    Some post-receive hooks require additional variables. Run:
        gpd describe-hook --project <project>.

DEFAULTS
    --start-branch: master
    --bare-repo-root-dir: $GPD_BARE_REPO_ROOT_DIR or $HOME/gpdrepos
    --devstack-home-dir: $GPD_DEVSTACK_HOME_DIR or $HOME/devstack
    --localrc-repo-dir: <project>_REPO where project derived from --start-repo
    --dest-repo-dir: /opt/stack/<project> where project derived from --start-repo

ENVIRONMENT VARIABLES
    GPD_BARE_REPO_ROOT_DIR: Absolute path to dir in which to create all bare
                            repos on DevStack VM
    GPD_DEVSTACK_HOME_DIR: Absolute path to DevStack clone
    GPD_VERBOSE: 1 to show extra output
```

### gpd setup-remote

```bash
$ gpd setup-remote --help

NAME
    gpd setup-remote - setup git remote on local clone

USAGE
    gpd setup-remote -w|--git-work-dir <git-work-dir>
                     -s|--server <server>
                     [-u|--remote-user <remote-user>]
                     [-b|--bare-repo-root-dir <bare-repo-root-dir]
                     [-r|--remote-name <remote-name>]
                     [-p|--project <project>]
                     [-v|--verbose]
                     [-h|--help]

DEFAULTS
    --remote-user: $(whoami)
    --bare-repo-root-dir: $HOME/gpdrepos
    --remote-name: derived from --server
    --project: derived from "origin" remote found at --git-work-dir

ENVIRONMENT VARIABLES
    GPD_REMOTE_USER: User on DevStack VM to use with git (via ssh)
    GPD_BARE_REPO_ROOT_DIR: Absolute path to dir containing all bare repos on
                            DevStack VM
    GPD_AUTO_REMOTE_NAME_PREFIX: When --remote_name not specified, add this
                                 prefix to remote name derived from --server
    GPD_AUTO_REMOTE_NAME_SUFFIX: When --remote_name not specified, add this
                                 suffix to remote name derived from --server
    GPD_VERBOSE: 1 to show extra output
```