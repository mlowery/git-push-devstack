# git-push-devstack

## Introduction

git-push-devstack (gpd) is a development workflow for OpenStack. With gpd, `git
push` serves as a mechanism for copying changes from your laptop (or wherever
you code) to your DevStack VM. `git push` also serves as a mechanism to trigger
any restarts or other actions upon uploading new code.

First, let's look at how to use it and then we'll describe how it works.

Step 1 is to run `gpd vm` on your DevStack VM after cloning DevStack but before
running `stack.sh`:

```bash
git clone https://github.com/openstack-dev/devstack.git ~/devstack
sudo mkdir -p /opt/stack && sudo chown $(whoami) /opt/stack
git clone https://github.com/mlowery/git-push-devstack.git
cd git-push-devstack/bin && ./gpd vm --start-repo https://github.com/openstack/horizon.git
cd ~/devstack && ./stack.sh
```

Step 2 is to run `gpd laptop` wherever you do your coding:

```bash
git clone https://github.com/openstack/horizon.git ~/horizon
gpd laptop --project horizon --git-work-dir ~/horizon --host horizontest.example.com
cd ~/horizon
# make some changes
git commit -a
git push gpd-horizontest
```

The entire goal of gpd is to handle the staging of your local changes to a
DevStack VM. Using gpd means that after making some changes, you copy to your
DevStack VM using:

```bash
git commit -a
git push gpd-horizontest
```

While there is a commit necessary per push, you get built-in push history by
doing so (use interactive rebase to squash commits before submitting to
Gerrit). And if you hate commit proliferation, use `--amend` every time.

## Who's It For

gpd was built for OpenStack developers who have an OpenStack cloud at their
disposal for development purposes. But there's nothing preventing you from
using it with Vagrant.

## How It Works

`gpd vm` sets up a [bare repository](http://git-scm.com/book/en/Git-on-the-Server-Getting-Git-on-a-Server)
with a [post-receive](http://git-scm.com/book/en/Customizing-Git-Git-Hooks)
hook. The bare repository accepts whatever you push from your laptop, then
copies those changes to `/opt/stack/<project>` (or wherever `$DEST` is).
Additionally, services are restarted during the hook--in general, whatever is
necessary for your changes to fully take effect (e.g. `service apache2 restart`).

`gpd laptop` sets up a [remote](http://git-scm.com/book/en/Git-Basics-Working-with-Remotes)
which is just a destination for your git pushes.

## Best Practices

* For `gpd vm`, run it from Puppet, or Fabric, or User Data, or ssh. It's not
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