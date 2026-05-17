# Build and Install FreeSWITCH on Debian 12

Interactive Bash script to build and install **FreeSWITCH** from source on Debian 12 — **without requiring a SignalWire token**.

This script automates the full build process and configures a production-ready environment with a dedicated system user, a `systemd` service, symbolic links to standard Debian paths, and a global `PATH` for the FreeSWITCH binaries.

---

## Why this script?

Since **2023**, SignalWire (the main sponsor of FreeSWITCH) moved their official Debian/Ubuntu package repositories behind an **authentication token**. To install FreeSWITCH from `.deb` packages, you now need to create a SignalWire account and generate a Personal Access Token (PAT).

This is fine for many users, but it can be inconvenient if:

- You cannot or do not want to create a SignalWire account (In my case i live in Ivory Coast and I can't verify my phone number)
- You want full control over the build (modules, compilation flags)
- You need a specific version not packaged by SignalWire
- You simply prefer building from official upstream sources

This script gives you a **clean, reproducible, source-based installation** straight from the [official GitHub repository](https://github.com/signalwire/freeswitch) — no token, no account, no third-party repository.

---

## Installation

```bash
git clone https://github.com/raystone06/build-and-install-freeswitch-on-debian-12.git
cd build-and-install-freeswitch-on-debian-12
sudo bash build-and-install-freeswitch.sh
```

---

## What this script does

- Prompts you interactively for the **installation path** and **FreeSWITCH version**
- Installs all required build dependencies
- Compiles the four required libraries: `libks`, `signalwire-c`, `spandsp`, `sofia-sip`
- Clones FreeSWITCH from the official repo and builds it
- Disables `mod_signalwire` by default (see [Disabled modules](#disabled-modules))
- Creates a dedicated `freeswitch` system user/group
- Sets correct ownership and permissions
- Creates symbolic links to standard Debian locations:
  - `/etc/freeswitch` → configuration
  - `/var/log/freeswitch` → logs
  - `/var/lib/freeswitch` → data
  - `/var/run/freeswitch` → runtime files
- Adds the FreeSWITCH `bin/` directory to the global `PATH`
- Installs a hardened `systemd` service
- Enables and starts the service automatically

The script will then ask you two questions:

1. **Installation path** (default: `/opt/freeswitch`)
2. **FreeSWITCH version** (default: `master`)

You can press `ENTER` to accept the defaults, or provide your own values.

---

## Requirements

- **OS**: Debian 12 (Bookworm) — fresh install recommended
- **Privileges**: root access (script uses `sudo`)
- **Disk**: at least **3 GB** free (for sources, build artifacts and the final installation)
- **RAM**: 2 GB minimum (4 GB recommended for faster compilation)
- **Network**: internet access (to fetch dependencies and clone repositories)

---

## Build time

Expect the full build to take **20 to 30 minutes** on modern hardware (more on low-end machines or VMs with limited CPU). The longest steps are the compilation of `spandsp`, `sofia-sip`, and FreeSWITCH itself.

You can leave the script running unattended — it does not require interaction after the initial prompts.

---

## After installation

The script installs a profile script in `/etc/profile.d/freeswitch.sh` that adds the FreeSWITCH binaries to the global `PATH`. To use it immediately in your current shell:

```bash
source /etc/profile.d/freeswitch.sh
```

Otherwise, just open a new bash session.

---

## Disabled modules

The script **disables `mod_signalwire`** by default during the build. This module connects FreeSWITCH to the SignalWire cloud platform and is not needed for a standard local installation.

Disabling it removes another potential dependency on SignalWire infrastructure and keeps the installation fully self-hosted.

If you want to enable it (or disable other modules), edit the `REMOVED_MODULES` array near the top of the script:

```bash
REMOVED_MODULES=(
    mod_signalwire
#   mod_pgsql
)
```

Comment out a line with `#` to keep the module, or add a new line to disable another module.

---

## Configuration

After installation, all configuration files are accessible via the standard Debian path thanks to the symbolic link:

```
/etc/freeswitch -> <PREFIX>/etc/freeswitch
```

Main files of interest:

- `/etc/freeswitch/vars.xml` — global variables (default passwords, IPs, etc.)
- `/etc/freeswitch/sip_profiles/internal.xml` — internal SIP profile (port 5060)
- `/etc/freeswitch/sip_profiles/external.xml` — external SIP profile (port 5080)
- `/etc/freeswitch/dialplan/default.xml` — call routing logic
- `/etc/freeswitch/directory/default/` — SIP users (1000 to 1019 by default)

---

## Uninstall

To completely remove FreeSWITCH installed by this script:

```bash
sudo systemctl stop freeswitch
sudo systemctl disable freeswitch
sudo rm -f /etc/systemd/system/freeswitch.service
sudo rm -f /etc/default/freeswitch
sudo rm -f /etc/profile.d/freeswitch.sh
sudo rm -f /etc/freeswitch /var/log/freeswitch /var/lib/freeswitch /var/run/freeswitch
sudo rm -rf /opt/freeswitch     # or your custom PREFIX
sudo userdel freeswitch
sudo groupdel freeswitch
sudo systemctl daemon-reload
```

---

## Credits

The original build logic is adapted from the excellent gist by [Mario Gasparoni](https://gist.github.com/mariogasparoni/dc4490fcc85a527ac45f3d42e35a962c), with significant enhancements for production deployment.

FreeSWITCH itself is developed and maintained by the [SignalWire team and the FreeSWITCH community](https://github.com/signalwire/freeswitch).

---

## Author

**Laurent Raymond**

- LinkedIn: [linkedin.com/in/laurent-raymond-aka](https://www.linkedin.com/in/laurent-raymond-aka/)
- GitHub: [github.com/raystone06](https://github.com/raystone06)

If you have a project, a question, or just want to chat about VoIP, FreeSWITCH, or telecom in general — feel free to reach out. I would love to hear from you.

Made with passion in Abidjan, Côte d'Ivoire.
