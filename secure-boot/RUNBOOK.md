# Secure Boot and FACEIT runbook

This is the recovery and maintenance guide for the `nixos` host. Read it
before changing Secure Boot keys or bootloader files.

## Known-good design

The machine is a Corsair Vengeance i8100 with an ASUS PRIME Z790-P WIFI board.
Windows and NixOS are on separate drives and separate EFI System Partitions
(ESPs):

- Windows: `/dev/nvme1n1p1`, partition UUID
  `38275e23-2fe9-435b-a9ce-31cb6e511e4b`
- NixOS `/boot`: `/dev/nvme0n1p1`, partition UUID
  `354116f3-dcd1-4d3f-8cbc-14c666fef2bd`

Device names such as `nvme0n1` can change. Trust the partition UUIDs and
`findmnt /boot`, not the device names, during recovery.

The trust chain is:

```text
ASUS factory PK/KEK/db
└── Microsoft UEFI CA 2011 or 2023
    └── Fedora shim 16.1-7 (shimx64.efi)
        └── Chase NixOS Shim MOK
            └── Lanzaboote systemd-boot (named grubx64.efi for shim)
                └── MOK-signed NixOS generation EFI image
```

Shim calls its second stage `grubx64.efi` by convention. That file is
systemd-boot here; GRUB is not used.

Important trust boundaries:

- Firmware retains its factory Microsoft/OEM keys. Never use `sbctl
  enroll-keys`, Lanzaboote automatic enrollment, or clear the firmware keys as
  part of normal maintenance.
- The local certificate is enrolled only in shim's MOK database.
- Windows is booted directly through Microsoft Windows Boot Manager. It is not
  chainloaded through shim or systemd-boot. This gives Windows the boot
  measurements expected by FACEIT.
- FACEIT was tested successfully with this arrangement and Secure Boot on.

## Important files

```text
/var/lib/shim-mok/keys/db/db.key  Private signing key; root-only; never commit
/var/lib/shim-mok/keys/db/db.pem  PEM public certificate used by Lanzaboote
/var/lib/shim-mok/keys/db/db.der  DER public certificate enrolled in MOK

/boot/EFI/NixOS-shim/shimx64.efi  Microsoft-signed Fedora shim
/boot/EFI/NixOS-shim/mmx64.efi    Fedora-signed MokManager
/boot/EFI/NixOS-shim/fbx64.efi    Fedora-signed fallback manager
/boot/EFI/NixOS-shim/grubx64.efi  MOK-signed systemd-boot second stage
/boot/EFI/Linux/*.efi             MOK-signed NixOS generations
```

The private key is intentionally outside Git and the Nix store. Losing it
means future generations cannot be signed with the enrolled MOK.

## Back up the signing key

Make an encrypted, offline backup of the entire `/var/lib/shim-mok` directory.
Do not put it in this repository, cloud storage as plaintext, or a world
readable location. Record the backup procedure and storage location in a
password manager, not here.

Example archive creation, after choosing a secure mounted destination:

```console
sudo tar --create --xz --file /secure/offline/location/shim-mok-backup.tar.xz \
  --directory /var/lib shim-mok
sudo chmod 0600 /secure/offline/location/shim-mok-backup.tar.xz
```

Prefer encrypting the archive or storing it on an encrypted removable drive.
Test that the archive lists correctly before relying on it. Never paste the
private key or archive contents into an issue, chat, or command output.

## Normal operation

Normal power-on boots NixOS through the firmware entry named `NixOS`. To boot
Windows directly for one boot:

```console
sudo winboot
```

The desired firmware order is NixOS first and Windows second. Numeric IDs can
change, so identify entries by labels and paths rather than assuming the old
IDs:

```console
nix shell nixpkgs#efibootmgr -c efibootmgr
```

Expected paths:

```text
NixOS:                \EFI\NixOS-shim\shimx64.efi
Windows Boot Manager: \EFI\Microsoft\Boot\bootmgfw.efi
```

The direct `Linux Boot Manager` and `UEFI OS` entries do not pass through shim.
They are useful only as recovery paths with Secure Boot disabled.

## Rebuilding and upgrading NixOS

Use the normal workflow:

```console
sudo nixos-rebuild dry-build --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

Lanzaboote signs each generation using the existing MOK. The
`stage-nixos-shim.path` unit watches the signed systemd-boot loader, and
`stage-nixos-shim.service` copies it to shim's expected `grubx64.efi` path.
The service also runs at boot.

After changes to Nixpkgs, systemd, Lanzaboote, the kernel, or this Secure Boot
configuration, check:

```console
sudo systemctl status --no-pager stage-nixos-shim.service
sudo bootctl status
sudo nix shell nixpkgs#mokutil -c mokutil --sb-state
```

An inactive/dead `stage-nixos-shim.service` is normal for this one-shot unit
when its most recent result is `status=0/SUCCESS`.

Verify all installed signatures when troubleshooting or before a risky
reboot:

```console
sudo nix shell nixpkgs#sbsigntool -c bash -c '
for file in \
  /boot/EFI/NixOS-shim/grubx64.efi \
  /boot/EFI/systemd/systemd-bootx64.efi \
  /boot/EFI/Linux/*.efi
do
  [[ -e "$file" ]] || continue
  echo "Checking: $file"
  sbverify --cert /var/lib/shim-mok/keys/db/db.pem "$file"
done
'
```

Every file must report `Signature verification OK`. Do not reboot into an
unverified new generation with Secure Boot enabled.

## Known-good status

From a successful NixOS shim boot, `sudo bootctl status` should show:

```text
Secure Boot: enabled (user)
Current Boot Loader: systemd-boot
Retain SHIM protocols: supported
Loader: /boot/EFI/NixOS-shim/grubx64.efi
Current Stub: lanzastub
```

Verify the MOK only after booting through shim; shim creates the runtime MOK
mirror used by `mokutil`:

```console
sudo nix shell nixpkgs#mokutil -c mokutil \
  --test-key /var/lib/shim-mok/keys/db/db.der
```

Expected: `db.der is already enrolled`. If NixOS was booted directly through
`Linux Boot Manager`, this command can misleadingly say `not enrolled` because
shim did not create `MokListRT` during that boot.

## FACEIT and Windows checks

Always enter Windows through `Windows Boot Manager`, normally with `sudo
winboot`. Do not select Windows from a Linux bootloader menu.

In Windows, run `msinfo32` and confirm:

```text
BIOS Mode: UEFI
Secure Boot State: On
```

Also confirm TPM 2.0 is ready in `tpm.msc` and Windows Security. If FACEIT
fails, record the exact error before changing anything. Confirm Windows was
booted directly and check Secure Boot/TPM first.

Do not respond to a FACEIT failure by clearing firmware keys or enrolling the
MOK into firmware. FACEIT recommends `Windows UEFI Mode` on ASUS firmware and
factory keys. A BIOS or Windows security update may also be required.

Keep the BitLocker recovery key available. Firmware, Secure Boot, TPM, boot
order, and BIOS updates can trigger BitLocker recovery.

## Symptom: NixOS no longer boots with Secure Boot enabled

1. Enter ASUS firmware setup and temporarily disable Secure Boot. Do not clear
   any keys.
2. Boot the `NixOS`, `Linux Boot Manager`, or `UEFI OS` entry.
3. Check the staging service and signatures using the commands above.
4. Check that the MOK files still exist and have safe permissions:

   ```console
   sudo ls -l /var/lib/shim-mok/keys/db
   ```

5. Rebuild the boot artifacts:

   ```console
   sudo nixos-rebuild boot --flake .#nixos
   sudo systemctl start stage-nixos-shim.service
   ```

6. Verify signatures, then re-enable Secure Boot and test the `NixOS` entry.

If firmware reports `Security Violation` before systemd-boot appears, suspect
shim revocation, missing Microsoft third-party CA trust, an outdated firmware
certificate database, or the wrong EFI entry. If systemd-boot appears but a
generation fails, suspect an unsigned/corrupt generation or signing-key
mismatch.

## Symptom: MOK appears missing

First ensure the current boot used the `NixOS` shim entry. Then run:

```console
sudo nix shell nixpkgs#mokutil -c mokutil --list-new
sudo nix shell nixpkgs#mokutil -c mokutil --list-enrolled
sudo nix shell nixpkgs#mokutil -c mokutil \
  --test-key /var/lib/shim-mok/keys/db/db.der
```

If the key really is absent, import only the public DER certificate:

```console
sudo nix shell nixpkgs#mokutil -c mokutil \
  --import /var/lib/shim-mok/keys/db/db.der
```

Set a temporary password, set the NixOS shim entry for the next boot, reboot,
and choose `Enroll MOK` → `Continue` → `Yes` in MokManager. Enter the temporary
password. Do not choose enroll-hash, enroll-key-from-disk, or disable
validation.

The helper below selects NixOS for one boot without changing persistent order:

```console
sudo nix run .#test-shim-boot
```

After MokManager reboots, boot NixOS through shim once more before using
`mokutil --test-key`; otherwise the runtime MOK mirror will be absent.

## Symptom: signing key is missing or damaged

Do not run `create-shim-mok` if any old key file still exists. It deliberately
refuses to overwrite keys.

Restore `/var/lib/shim-mok` from the offline backup with the original ownership
and permissions. Rebuild and verify the EFI artifacts.

If no backup exists, recovery requires a new key and another physical MOK
enrollment:

1. Disable Secure Boot and boot NixOS directly.
2. Preserve the damaged directory for diagnosis; do not overwrite it.
3. Move it to a specifically named backup location.
4. Run `sudo nix run .#create-shim-mok` to create a new key.
5. Run `sudo nixos-rebuild boot --flake .#nixos` and stage the loader.
6. Enroll the new `db.der` through MokManager.
7. Verify every generation. Old generations signed only by the lost key will
   not boot unless that old public certificate remains enrolled.

Changing the signing key is a recovery operation, not routine rotation.

## Symptom: EFI entry is missing or boot order changed

BIOS updates and firmware resets commonly change NVRAM entries and order.
Inspect the current state with `efibootmgr`. To recreate NixOS, first resolve
the current ESP device rather than copying an old device name:

```console
findmnt /boot
lsblk -o NAME,PATH,PARTN,PARTUUID,MOUNTPOINTS
```

Then create an entry using the resolved disk and partition. For the currently
documented layout this is:

```console
sudo nix shell nixpkgs#efibootmgr -c efibootmgr \
  --create-only \
  --disk /dev/nvme0n1 \
  --part 1 \
  --label NixOS \
  --loader '\EFI\NixOS-shim\shimx64.efi'
```

Do not assume the new `BootXXXX` number. List entries again, find the numbers
for `NixOS` and `Windows Boot Manager`, then set NixOS first and Windows
second. Preserve other entries until the machine has rebooted successfully.

## Symptom: `sudo winboot` fails

`winboot` searches for a firmware entry exactly named `Windows Boot Manager`,
sets it as `BootNext`, and reboots. It does not change `BootOrder`.

If it cannot find Windows:

1. Run `efibootmgr` and check whether the label changed or disappeared.
2. Check that the Windows ESP with partition UUID
   `38275e23-2fe9-435b-a9ce-31cb6e511e4b` still exists.
3. Use ASUS's one-time boot menu to select Windows while repairing the entry.
4. Prefer Windows recovery tools to recreate Windows Boot Manager. Never point
   `winboot` at a Linux chainloader for FACEIT use.

## Firmware updates and factory-key resets

Before a BIOS update:

1. Save the BitLocker recovery key.
2. Back up `/var/lib/shim-mok` offline.
3. Record `efibootmgr -v`, MOK status, and `bootctl status`.
4. Have a recent NixOS installer USB available. The standard installer may
   require temporarily disabling Secure Boot.

After the update, verify:

- Secure Boot is enabled in ASUS `Windows UEFI Mode`.
- Factory Microsoft/OEM keys remain provisioned.
- The NixOS and Windows firmware entries still exist in the right order.
- The MOK remains enrolled when booted through shim.
- NixOS signatures verify and Windows still reports Secure Boot on.

`Restore Factory Keys` restores firmware PK/KEK/db. A firmware reset may also
erase boot entries or MOK-related EFI variables, depending on the board and
reset operation. It is a recovery fallback, not a normal troubleshooting step.
Be prepared to recreate the NixOS entry and re-enroll the MOK afterward.

## Updating shim

The shim RPM is intentionally pinned by version and SHA-256 in
`fedora-shim.nix`. Do not casually update it along with ordinary packages.

Reasons an update may become necessary:

- Microsoft or Fedora revokes the current shim through dbx or SBAT.
- Firmware stops trusting the 2011 CA and requires the 2023 chain.
- A shim security advisory requires replacement.
- The pinned Rawhide RPM URL disappears after Fedora repository rotation.

The current shim contains both Microsoft UEFI CA 2011 and 2023 signatures.
For a candidate replacement:

1. Use an official Fedora artifact from the signing-service-signed `shim-x64`
   package.
2. Pin the exact content hash.
3. Confirm both Authenticode chains as appropriate:

   ```console
   nix build .#fedora-shim
   nix shell nixpkgs#sbsigntool -c sbverify --list result/shimx64.efi
   ```

4. Inspect `.sbat` with `objdump -s -j .sbat`.
5. Confirm Fedora-signed `mmx64.efi` is from the same package.
6. Stage without changing the firmware entry and verify the MOK-signed second
   stage.
7. Test a one-shot NixOS boot before relying on the update.
8. Keep the previous known-good shim available until the replacement boots
   successfully under Secure Boot.

A valid Microsoft signature alone does not guarantee that firmware dbx or the
current SBAT policy has not revoked a binary.

## Emergency recovery checklist

Keep a recent installer USB and the BitLocker recovery key available.

If neither normal NixOS entry works:

1. Disable Secure Boot; do not clear keys.
2. Try `Linux Boot Manager` or `UEFI OS`.
3. If necessary, boot the NixOS installer and mount the root and ESP.
4. Restore the signing key if it was lost.
5. Enter the installed system and run `nixos-rebuild boot`.
6. Re-stage `EFI/NixOS-shim` and verify signatures.
7. Recreate the NixOS firmware entry if necessary.
8. Re-enable Secure Boot only after an unsigned-mode test boot succeeds.

Windows remains independently bootable through its own disk and Microsoft
Boot Manager throughout this design. In the worst case, use ASUS firmware to
select Windows directly. Restoring factory keys should preserve Windows trust,
but may require BitLocker recovery and redoing the Linux MOK setup.

## Authoritative references

- [FACEIT: Enabling Secure Boot](https://support.faceit.com/hc/en-us/articles/4406281700370-Enabling-Secure-Boot)
- [FACEIT: Windows security requirements FAQ](https://support.faceit.com/hc/en-us/articles/23117181142556-Windows-Security-Requirements-FAQ)
- [rhboot shim README](https://github.com/rhboot/shim/blob/main/README.md)
- [mokutil manual](https://github.com/lcp/mokutil/blob/master/man/mokutil.1)
- [Microsoft guidance for Linux distributions using the 2023 UEFI CA](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/linux-distribution-guidance-handling-2023keys?view=windows-11)
- [Fedora `shim-x64` package](https://packages.fedoraproject.org/pkgs/shim/shim-x64/)
- [Lanzaboote documentation](https://nix-community.github.io/lanzaboote/)
