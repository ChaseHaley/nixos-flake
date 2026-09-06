# Shim Secure Boot

This directory documents the Microsoft-signed shim boot chain used by this
host. The configuration installs files only below `EFI/NixOS-shim`; it does
not modify anything below `EFI/Microsoft` or enroll keys into the firmware.

The flake package `.#fedora-shim` extracts `shimx64.efi`, `mmx64.efi`, and
`fbx64.efi` from Fedora's `shim-x64-16.1-7` RPM. The RPM is fetched from the
official Fedora repository and pinned by SHA-256. Fedora's changelog identifies
16.1-6 and later as carrying the Microsoft UEFI CA 2023 x64 signature.

Local inspection confirms that `shimx64.efi` is dual-signed through both the
Microsoft Corporation UEFI CA 2011 and Microsoft UEFI CA 2023 chains. Its SBAT
metadata identifies upstream shim 16.1 and Fedora generation 3. MokManager and
fallback are signed by Fedora's certificate embedded in Fedora's shim.

Build and inspect the staged files with:

```console
nix build .#fedora-shim
nix shell nixpkgs#sbsigntool -c sbverify --list result/shimx64.efi
nix shell nixpkgs#sbsigntool -c sbverify --list result/mmx64.efi
objdump -s -j .sbat result/shimx64.efi
```

## NixOS second stage

Lanzaboote is configured strictly as the NixOS artifact signer and generation
manager. Its certificate lives under `/var/lib/shim-mok` and is enrolled only
in shim's MOK database. `autoEnrollKeys` is deliberately disabled: this
configuration must never replace or supplement the firmware's factory PK,
KEK, or db.

The complete NixOS closure, including Lanzaboote 1.1.0 and its UEFI stub, has
been built without activation. A disposable signing certificate was also used
to sign and successfully verify the built systemd-boot x64 EFI second stage.

Before the first rebuild with Lanzaboote, explicitly create the signing key:

```console
sudo nix run .#create-shim-mok
```

This command refuses to overwrite an existing key and does not modify EFI
variables. The private key remains root-only. The public `db.der` certificate
must be enrolled through `mokutil` and confirmed physically in MokManager.

After activation, `stage-nixos-shim.service` maintains an isolated directory:

```text
/boot/EFI/NixOS-shim/shimx64.efi  Microsoft-signed Fedora shim
/boot/EFI/NixOS-shim/mmx64.efi    Fedora-signed MokManager
/boot/EFI/NixOS-shim/fbx64.efi    Fedora-signed fallback manager
/boot/EFI/NixOS-shim/grubx64.efi  MOK-signed Lanzaboote systemd-boot
```

Shim expects the second stage to be named `grubx64.efi`; it is systemd-boot in
this design, not GRUB. A systemd path unit re-stages it whenever Lanzaboote
updates the signed loader. This directory does not replace `EFI/BOOT`,
`EFI/systemd`, or anything below `EFI/Microsoft`.

## One-shot NixOS boot

With Secure Boot still disabled, prepare a one-shot boot through shim using:

```console
sudo nix run .#test-shim-boot
```

This reuses the `NixOS` firmware entry and sets only `BootNext`. If the entry is
missing, it creates one with `efibootmgr --create-only`, leaving the persistent
`BootOrder` unchanged. It does not reboot, enroll a MOK, or change Secure Boot.

The normal firmware order has NixOS first and Windows Boot Manager second.
Run `sudo winboot` from NixOS to boot Windows directly for one boot. This keeps
the Windows TPM measurement chain independent of shim and is confirmed to work
with FACEIT Anti-Cheat while Secure Boot remains enabled.
