# dracut-crypt-ssh

A Debian-friendly fork of [dracut-crypt-ssh/dracut-crypt-ssh](https://github.com/dracut-crypt-ssh/dracut-crypt-ssh) that provides easier installation and configuration on Debian-based systems.

[Original README](README.old.md) | [Upstream repository](https://github.com/dracut-crypt-ssh/dracut-crypt-ssh)

## About original project

dracut-crypt-ssh is a dracut module that allows you to remotely unlock LUKS-encrypted system drive over SSH during the initramfs stage of the boot process. It is useful for headless systems like servers which do not have a keyboard or monitor attached.

## Why this fork?

Debian uses `initramfs-tools` as its default initramfs generator and provides `dropbear-initramfs` package for remote access to the initramfs.

However, this setup does not provide the same TPM 2.0 integration available with `dracut` for automatically unlocking LUKS volumes. Using dracut allows LUKS volumes to be integrated with TPM 2.0-based unlocking mechanisms.

Even with TPM 2.0 automatic unlocking, you may still need to enter a LUKS passphrase when using strict PCR policies. For example, regenerating the initramfs after a kernel update can change the measured boot state and cause the TPM to refuse automatic unlocking.

## Changes in this fork

Code of the dracut-crypt-ssh module itself has not been changed, but several other modifications have been made to simplify the installation and usage of the module on Debian-based systems. This includes:

- The project is packaged as a Debian package that can be installed using `apt` instead of manually building the module from source.
- Packages are automatically built by GitHub Actions for releases.
- Release packages include GitHub artifact attestations that can be used to verify their provenance and integrity.
- Added a custom `fixshell` dracut module that works around an issue with the shell available in the initramfs. It modifies `/etc/passwd` and `/etc/shells` inside the initramfs so that the `root` user's shell is `/bin/sh` and `/bin/sh` is listed as a valid shell. These changes affect only the initramfs; the corresponding files on the installed system are not modified.
- SSH host keys for the initramfs are generated during package installation. This avoids having to generate them manually and prevents the default module behavior of generating new host keys every time the initramfs is rebuilt.
- The default module configuration is modified to use the SSH host keys generated during package installation.
- The default `authorized_keys` location is changed so that the keys used for initramfs SSH access are stored separately from `/root/.ssh/authorized_keys` on the installed system.

## Installation

### 1. Install the package

Download the `.deb` package from the latest release and install it with `apt`:

```bash
wget https://github.com/bartekl1/dracut-crypt-ssh/releases/download/v1.0.8/dracut-crypt-ssh_1.0.8-1_amd64.deb
sudo apt install ./dracut-crypt-ssh_1.0.8-1_amd64.deb
```

> [!NOTE]
> The URL above is an example for version `1.0.8`. Check the [latest release](https://github.com/bartekl1/dracut-crypt-ssh/releases/latest) and update the URL if necessary.

> [!TIP]
> It is recommended to use `apt` instead of `dpkg` as it will automatically resolve and install any missing dependencies.

### 2. Configure networking in the initramfs

Configure GRUB to start networking in the initramfs.

Edit `/etc/default/grub` and add `rd.neednet=1` and an appropriate `ip=` configuration to `GRUB_CMDLINE_LINUX`.

For DHCP:

```text
GRUB_CMDLINE_LINUX="rd.auto rd.luks=1 rd.neednet=1 ip=dhcp"
```

For a static IP, replace `ip=dhcp` with your network configuration. For example:

```text
ip=192.168.0.100::192.168.0.1:255.255.255.0::eth0:off
```

After modifying the configuration, update GRUB:

```bash
sudo update-grub
```

> [!IMPORTANT]
> Make sure that the network interface name (`eth0` in the example above) matches the interface available during the initramfs stage.

### 3. Configure `dracut-crypt-ssh`

The package configuration file is located in:

```text
/etc/dracut.conf.d/crypt-ssh.conf
```

Modify this file if you need to change the default configuration, such as the SSH port or SSH host key paths.

In most cases, you will not need to modify this file. The default configuration should work out of the box for most users.

### 4. Add your SSH public key

Add the public key that should be allowed to connect to the initramfs to:

```text
/etc/dracut-crypt-ssh/authorized_keys
```

For example, to import the keys from your current user's `authorized_keys`:

```bash
cat ~/.ssh/authorized_keys | sudo tee -a /etc/dracut-crypt-ssh/authorized_keys
```

### 5. Regenerate the initramfs

Regenerate all installed initramfs images:

```bash
sudo dracut -f --regenerate-all
```

If you only need to regenerate the initramfs for the currently running kernel, you can use:

```bash
sudo dracut -f
```

## Usage

After booting into the initramfs, connect to the system over SSH using the configured port. The default port is `222` and the SSH user is `root`.

For example:

```bash
ssh -p 222 root@<IP_ADDRESS>
```

Once connected, you can use the following commands:

- `console_peek` — displays what is currently shown on the system console.
- `console_auth` — sends a passphrase entered through SSH to the console.

Use `console_peek` to check whether the system is waiting for a LUKS passphrase, then use `console_auth` to provide it.

## Configuration

The main configuration file is:

```text
/etc/dracut.conf.d/crypt-ssh.conf
```

The SSH public keys used for authentication are stored in:

```text
/etc/dracut-crypt-ssh/authorized_keys
```

SSH host keys used by the initramfs are generated during package installation.

## Building from source

Install build dependencies:

```bash
sudo apt update
sudo apt install build-essential devscripts debhelper dh-make libblkid-dev dracut
```

> [!CAUTION]
> Installation `dracut` on a standard Debian installation may cause `initramfs-tools` to be removed because both packages provide the initramfs generation infrastructure. Make sure you understand this change before installing the build dependencies on your main system.
>
> If you want to keep using `initramfs-tools`, or if you are unsure about the consequences, build the package in a virtual machine or another isolated Debian environment.

Make the `configure` script executable:

```bash
chmod +x configure
```

Build the package:

```bash
dpkg-buildpackage -us -uc -b
```

The resulting `.deb` package will be created in the parent directory.

## Security considerations

LUKS provides strong protection against offline access to encrypted data, but remote unlocking does not protect against a compromised boot environment.

If an attacker has physical access to the machine, they may be able to modify the bootloader, kernel, initramfs, or other components involved in unlocking the encrypted volume. For example, an attacker could replace executables that handle key material or extract the private SSH host keys from the initramfs.

This type of attack is not unique to `dracut-crypt-ssh`, but providing remote access to the initramfs may make some attacks easier to perform or conceal.

## License

This project is licensed under the [GNU General Public License v2.0](LICENSE), the same license as the upstream project.

The package is provided "as is" without any warranty. Use it at your own risk. I am not responsible for any damage, data loss or security breach.
