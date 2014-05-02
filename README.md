# git-push-devstack

## Introduction

git-push-devstack (gpd) is a development workflow for OpenStack projects.
gpd was built for OpenStack developers who want to code locally and automate
the copy-to-DevStack-VM-and-restart-services sequence.

## Requirements

gpd requires only bash and git.

## Installation

On both the VM and the laptop, the installation is just cloning this repository
and possibly adding the `bin` directory to your `PATH`.

## Setup

With gpd, `git
push` serves as a mechanism for copying changes from your laptop (or wherever
you code) to your DevStack VM. `git push` also serves as a mechanism to trigger
any restarts or other actions upon uploading new code.

First, let's look at how to use it and then we'll describe how it works.

Step 1 is to run `gpd setup-hook` on your DevStack VM after cloning DevStack but before
running `stack.sh`:

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

Step 2 is to run `gpd setup-remote` wherever you do your coding:

```bash
# clone OpenStack project (e.g. horizon)
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

The entire goal of gpd is to handle the staging of your local changes to a
DevStack VM. Using gpd means that after making some code changes, you copy to your
DevStack VM using:

```bash
git commit -a
git push gpd-horizontest
```

While there is a commit necessary per push, you get built-in push history by
doing so (use interactive rebase to squash commits before submitting to
Gerrit). And if you dislike commit proliferation, use `--amend` every time.

## How It Works

`gpd setup-hook` sets up a [bare repository](http://git-scm.com/book/en/Git-on-the-Server-Getting-Git-on-a-Server)
with a [post-receive](http://git-scm.com/book/en/Customizing-Git-Git-Hooks)
hook. The bare repository accepts whatever you push from your laptop, then
copies those changes to `/opt/stack/<project>` (or wherever `$DEST` is).
Additionally, services are restarted during the hook--in general, whatever is
necessary for your changes to fully take effect (e.g. `service apache2 restart`).

`gpd setup-remote` sets up a [remote](http://git-scm.com/book/en/Git-Basics-Working-with-Remotes)
which is just a destination for your git pushes. Pushes to the bare repository
are forced meaning you can jump between changes. Finally, just to be safe, all
changes in the `/opt/stack/<project> directory` are stashed or tagged to
prevent any local changes you may have made while hacking (but you should avoid
that kind of hacking).

## What OpenStack Projects Are Supported

There are `post-receive` hooks for the following projects:
* horizon
* trove
* trove-integration
* python-troveclient

Adding more post-receive hooks is as simple as adding a file to the
`post-receive` directory. Use `horizon.bash` as a starter template.

## Best Practices

* For `gpd setup-hook`, run it from Puppet, or Fabric, or User Data, or ssh. It's not
meant to be run manually.
* Take advantage of `GPD_*` environment variables to eliminate repeating
rarely-changing values. Example: If your DevStack VM user is always `ubuntu`,
set `GPD_REMOTE_USER` to `ubuntu`.

# References

* [Vagrant](http://www.vagrantup.com/)
* [DevStack](http://devstack.org/)
* [Fabric](http://www.fabfile.org/)
* [Puppet](http://puppetlabs.com/)
* [User Data](http://docs.openstack.org/user-guide/content/user-data.html)