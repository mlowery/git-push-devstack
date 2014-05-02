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
git clone https://github.com/openstack-dev/devstack.git ~/devstack
# clone gpd
git clone https://github.com/mlowery/git-push-devstack.git
# setup vm to receive pushes
cd git-push-devstack/bin && ./gpd setup-hook --start-repo https://github.com/openstack/horizon.git
# run DevStack's stack.sh
cd ~/devstack && ./stack.sh
```

### Step 2

Run `gpd setup-remote` on your laptop:

```bash
# clone OpenStack project (e.g. horizon) if not already cloned
git clone https://github.com/openstack/horizon.git ~/horizon
# setup laptop to send pushes
gpd setup-remote --project horizon --git-work-dir ~/horizon --vm horizontest.example.com
cd ~/horizon
# make some changes
git commit -a
# push your changes
git push gpd-horizontest
```

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
changes in the `/opt/stack/<project> directory` are stashed or tagged to
prevent any local changes you may have made while hacking (but you should avoid
that kind of hacking).

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