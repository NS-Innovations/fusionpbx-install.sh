# Switching FreeSWITCH from Package to Source (Debian)

These steps convert an already installed and working FusionPBX server from the
SignalWire FreeSWITCH **packages** to a FreeSWITCH **source** build, using the
existing installer scripts.

The installer has no package-to-source script. `source-to-package.sh` goes the
other way and was written for the old `/usr/local/freeswitch` layout.

To update FreeSWITCH once it's a source install, see
[Updating a source install](#updating-a-source-install).

## Why this is straightforward

`source-release.sh` configures FreeSWITCH with:

```
--prefix=/usr --localstatedir=/var --sysconfdir=/etc
```

These are the same paths the packages use:

| Item                 | Path                     |
|----------------------|--------------------------|
| Binary               | `/usr/bin/freeswitch`    |
| Config               | `/etc/freeswitch`        |
| Recordings/voicemail | `/var/lib/freeswitch`    |
| Scripts/sounds       | `/usr/share/freeswitch`  |
| Logs                 | `/var/log/freeswitch`    |

Your config, recordings, voicemail, Lua scripts and fail2ban paths stay where
they are.

> **Warning:** Do **not** just set `switch_source=true` and run `switch.sh`.
> It also runs `conf-copy.sh`, which moves your working `/etc/freeswitch` to
> `/etc/freeswitch.orig` and replaces it with a fresh default config.

---

## 1. Record the current state and back up

```sh
# list the loaded modules so you can compare them after the switch
fs_cli -x 'show modules' > /root/fs-modules-before.txt

# back up config, data, scripts and the service files
tar czf /root/fs-backup-$(date +%F).tgz \
    /etc/freeswitch /var/lib/freeswitch /usr/share/freeswitch \
    /lib/systemd/system/freeswitch.service /etc/default/freeswitch
```

## 2. Set the config

Edit `/usr/src/fusionpbx-install.sh/debian/resources/config.sh`:

```sh
switch_branch=stable
switch_version=1.11        # or 1.10.12
```

Leave `sofia_version` as it is. `source-release.sh` reads these values; it
doesn't look at `switch_source` or `switch_package`. Setting `switch_source=true`
and `switch_package=false` keeps the file accurate for later runs.

## 3. (Optional) Compile ahead of time to cut downtime

The compile takes a while. You can build everything while the package version
of FreeSWITCH is still running. **Stop before `make install`.**

Either:

- Run the steps from `source-release.sh` by hand up to and including `make`
  (the libks, sofia-sip and spandsp builds, then `bootstrap.sh`, the
  `modules.conf` edits, `configure` and `make`).

Or:

- Skip this step and let `source-release.sh` do the whole build in step 5,
  during the maintenance window.

Notes for compiling by hand:

- **TLS certificate reload support.** Run this export before `configure`, as
  `source-release.sh` does. Without it the build still works, but
  `fs_cli -x reloadcert` isn't available.

  ```sh
  export CPPFLAGS="${CPPFLAGS} -DHAVE_NUA_RELOAD_TLS"
  ```

- **The dependency libraries are installed right away.** The libks, sofia-sip
  and spandsp builds each run `make install` and `ldconfig`, so the
  source-built libraries in `/usr/local/lib` take over immediately. If the
  package version of FreeSWITCH restarts before the maintenance window, it
  loads those libraries instead of its own. Keep the gap between this step
  and step 4 short.

## 4. Maintenance window: stop FreeSWITCH and remove the packages

You must remove the packages **before** `make install`. Otherwise removing the
packages deletes the new binaries and libraries, because dpkg still owns those
paths.

```sh
systemctl stop freeswitch

# dry run first, and check what will be removed
apt-get -s remove libfreeswitch1 | grep ^Remv

# this also removes freeswitch, freeswitch-mod-* and the meta packages
apt-get remove libfreeswitch1
```

- Use `remove`, **not** `purge`.
- **Don't** run `apt autoremove`.
- In the dry run, check that `freeswitch-sounds-*` (en/es/fr) are **not**
  listed. If the sound packages stay installed, the sounds stay in place and
  you don't need to run `source-sounds.sh`.
- If you like, delete the SignalWire repo so it isn't used again:
  `rm /etc/apt/sources.list.d/freeswitch.list`

## 5. Install the source build

```sh
cd /usr/src/fusionpbx-install.sh/debian/resources/switch
```

If you compiled ahead of time in step 3:

```sh
cd /usr/src/freeswitch-<version>
make install
ldconfig
mkdir -p /var/lib/freeswitch/storage/voicemail
cd /usr/src/fusionpbx-install.sh/debian/resources/switch
```

If you didn't, run the whole build now:

```sh
./source-release.sh
```

Then run these two scripts in either case:

```sh
./package-permissions.sh   # chown to www-data (same paths as the packages)
./package-systemd.sh       # installs the service file, enables and starts freeswitch
```

**Skip:**

- `conf-copy.sh`: it would overwrite your working `/etc/freeswitch`.
- `source-sounds.sh`: only needed if the sound packages were removed.

## 6. Check it

```sh
systemctl status freeswitch

# should point to /usr/local/lib for the source-built dependencies
ldd /usr/bin/freeswitch | grep -E 'sofia|spandsp|libks'

# compare loaded modules with what was loaded before the switch
fs_cli -x 'show modules' | diff /root/fs-modules-before.txt -
```

### Things that work differently from the package install

- **SignalWire libraries.** The packages brought in their own
  `libsofia-sip-ua` and `libspandsp` under `/usr/lib`. The source build
  installs its own copies to `/usr/local/lib`. If `ldd` shows FreeSWITCH
  linked to the wrong ones, remove the SignalWire library and `-dev` packages,
  then rebuild.
- **Missing modules.** The source `modules.conf` builds a smaller set than the
  packages installed:
  - Turned off on purpose: `mod_verto`, `mod_skinny`, `mod_signalwire`.
  - Not enabled by default: `mod_flite`, `mod_imagick`, `mod_tts_commandline`,
    `mod_distributor`, `mod_sms`.

  If you use any of these, enable them in
  `/usr/src/freeswitch-<version>/modules.conf` and rebuild (see "Rebuilding
  after a module change" below). Otherwise FreeSWITCH logs load errors for
  them in FusionPBX's Modules list.
- **PostgreSQL ordering.** `package-systemd.sh` installs a service file that
  doesn't start FreeSWITCH after `postgresql.service`. That ordering came from
  a `sed` in `package-release.sh`. To add it back:

  ```sh
  sed -i /lib/systemd/system/freeswitch.service \
      -e 's:local-fs.target:local-fs.target postgresql.service:'
  systemctl daemon-reload
  ```

---

## Updating a source install

The installer has no FreeSWITCH update script. You update a source install by
rebuilding in the existing source folder, `/usr/src/freeswitch-<version>`.

`source-release.sh` checks out `v1.11` as a **branch**, not a fixed tag, so
`git pull` in `/usr/src/freeswitch-1.11` picks up new 1.11.x releases. Check
what you're on with `freeswitch -version` or `git describe --tags`.

### Point release (for example 1.11.2 → 1.11.3)

```sh
# 1. record the current state and back up
freeswitch -version
fs_cli -x 'show modules' > /root/fs-modules-before.txt
tar czf /root/fs-backup-$(date +%F).tgz /etc/freeswitch

# 2. get the new code
cd /usr/src/freeswitch-1.11
git pull

# 3. reconfigure with the same options source-release.sh uses
rm -f config.cache
./bootstrap.sh -j
export CPPFLAGS="${CPPFLAGS} -DHAVE_NUA_RELOAD_TLS"
./configure -C --enable-portable-binary --disable-dependency-tracking --enable-debug \
  --prefix=/usr --localstatedir=/var --sysconfdir=/etc \
  --with-openssl --enable-core-pgsql-support

# 4. compile while FreeSWITCH is still running
make -j $(getconf _NPROCESSORS_ONLN)

# 5. short downtime: install and restart
systemctl stop freeswitch
make install && ldconfig
systemctl start freeswitch

# 6. check it
freeswitch -version
fs_cli -x 'show modules' | diff /root/fs-modules-before.txt -
```

What each part does:

- **Your config is safe.** `make install` only installs the sample config when
  `/etc/freeswitch` doesn't exist, so it won't touch your existing one.
- **Your module choices are kept.** `bootstrap.sh` only creates `modules.conf`
  if it's missing, so the installer's module edits stay in place.
- **Why the cache is deleted.** `rm -f config.cache` stops the
  `configure -C` cache from carrying over old results after the pull.
- **Rolling back:** run `git checkout v1.11.2` (or whichever version you were
  on) in the source folder, then repeat steps 3–5. Run `git checkout v1.11`
  afterwards to get back onto the branch.

### Rebuilding after a module change

To add a module you turned on in `modules.conf`, skip the `git pull` and
`configure`. Run `make`, then step 5.

### Dependencies (sofia-sip, spandsp, libks)

Only rebuild these when a new FreeSWITCH release needs it, or when
`sofia_version` in `config.sh` changes. Rebuild them **before** FreeSWITCH,
with `make install && ldconfig` in each folder.

- **Installed immediately.** The new libraries take effect as soon as they're
  installed, so do this inside the maintenance window.
- **sofia-sip needs a fresh download.** `/usr/src/sofia-sip` comes from a
  release zip, not git, so `git pull` won't work there. For a new version,
  delete the folder and download the new zip, which is what
  `source-release.sh` does.
- **libks and spandsp** are git clones.

### Major version (for example 1.10.12 → 1.11)

Change `switch_version` in `config.sh`, then stop FreeSWITCH and run
`switch/source-release.sh`. Don't run `switch.sh`, because it also runs
`conf-copy.sh`, which replaces your config. The script clones into a new
`freeswitch-<version>` folder and installs over the old binaries.

### Why not just run `source-release.sh` for every update?

You can, but the script has downsides for routine updates:

- It deletes the source folder and clones it again.
- It rebuilds the dependencies if their folders are more than 24 hours old.
- It runs `apt upgrade -y`.
- It runs `make install` without stopping FreeSWITCH first, so stop it
  yourself beforehand. That means downtime for the whole compile.

The manual steps above are faster and keep downtime to a minute or two.

### Do I have to stop FreeSWITCH before `make install`?

You don't strictly have to, but you should:

- **Why it usually doesn't crash.** `make install` uses `install`, which
  deletes the old file and writes a new one rather than writing over it. The
  running process keeps using the old binary and libraries it already has open.
- **Modules can get mixed.** Any module loaded after the install
  (`load mod_xxx`, `reload mod_xxx`, or one triggered from FusionPBX) comes
  from the new build. That module then runs inside the old core, and a
  core/module version mismatch can crash FreeSWITCH.
- **Restarts mid-install are risky.** systemd has `Restart=always`. If
  FreeSWITCH restarts partway through the install, it starts with a mix of old
  and new files.
- **New code only runs after a restart.** You have to restart to use the new
  build either way.

---

*Test this on a snapshot or spare server before doing it in production.*
