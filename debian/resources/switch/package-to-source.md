# Switching FreeSWITCH from Package to Source (Debian)

These steps convert an already installed and working FusionPBX server from the
SignalWire FreeSWITCH **packages** to a FreeSWITCH **source** build, using the
existing installer scripts.

The installer has no package-to-source script. `source-to-package.sh` goes the
other way and was written for the old `/usr/local/freeswitch` layout.

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
  `/usr/src/freeswitch-<version>/modules.conf`, then run `make && make install`
  again (see the rebuild steps below). Otherwise FreeSWITCH logs load errors
  for them in FusionPBX's Modules list.
- **PostgreSQL ordering.** `package-systemd.sh` installs a service file that
  doesn't start FreeSWITCH after `postgresql.service`. That ordering came from
  a `sed` in `package-release.sh`. To add it back:

  ```sh
  sed -i /lib/systemd/system/freeswitch.service \
      -e 's:local-fs.target:local-fs.target postgresql.service:'
  systemctl daemon-reload
  ```

---

## Later source rebuilds and upgrades

You don't strictly have to stop FreeSWITCH before `make install`, but you should:

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

Low-downtime rebuild:

```sh
cd /usr/src/freeswitch-<version>
make                          # while FreeSWITCH is still running
systemctl stop freeswitch
make install && ldconfig
systemctl start freeswitch
```

---

*Test this on a snapshot or spare server before doing it in production.*
