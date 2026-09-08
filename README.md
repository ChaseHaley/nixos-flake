# Chase's NixOS configuration

This flake manages both the `nixos` host and Chase's Home Manager profile.

## Layout

- `flake.nix`: pins inputs and connects the system, Home Manager, package, and app outputs.
- `hosts/nixos/configuration.nix`: imports the machine's NixOS modules.
- `hosts/nixos/hardware-configuration.nix`: generated, machine-specific hardware settings.
- `hosts/nixos/desktop.nix`: graphics, NVIDIA, Hyprland, gaming, and the greeter.
- `hosts/nixos/networking.nix`: networking, locale, and time zone settings.
- `hosts/nixos/system.nix`: system packages, Nix settings, zram, and system version.
- `hosts/nixos/users.nix`: user accounts and system-level shell setup.
- `home/chase/`: Chase's Home Manager configuration, split by concern.
- `secure-boot/`: shim package, NixOS integration, and maintenance apps.

## Apply changes

Flakes only see files tracked by Git. For this initial setup, add the new files:

```console
git add flake.nix flake.lock hosts home README.md .gitignore
```

Then preview the build:

```console
sudo nixos-rebuild dry-build --flake .#nixos
```

Then activate it:

```console
sudo nixos-rebuild switch --flake .#nixos
```

The `.#nixos` part selects `nixosConfigurations.nixos` from `flake.nix`.
Home Manager is integrated into the system rebuild, so a separate
`home-manager switch` command is not needed.

## Everyday workflow

1. Edit the relevant Nix file.
2. Run `git add` for any newly created file so the flake can see it.
3. Format with `nix fmt` if a formatter is added later.
4. Check with `nix flake check` or use the dry-build command above.
5. Review `git diff --cached` and `git diff`.
6. Apply with the switch command and commit the working configuration.

Update pinned inputs deliberately with:

```console
nix flake update
sudo nixos-rebuild switch --flake .#nixos
```

If a new generation causes trouble, select an older generation from the
systemd-boot menu, or run `sudo nixos-rebuild switch --rollback`.

Do not change either `stateVersion` just to upgrade packages. Those values
preserve compatibility; `nix flake update` controls dependency upgrades.

## Boot Windows directly

To reboot straight into the Windows Boot Manager for one boot:

```console
sudo winboot
```

This finds the firmware's `Windows Boot Manager` entry, sets UEFI `BootNext`
to it, and then reboots. It works when Windows and NixOS use different EFI
System Partitions and does not change the persistent boot order.

## Secure Boot operations

This machine uses a Microsoft-signed shim while retaining the ASUS factory
Secure Boot keys. Read the [Secure Boot runbook](secure-boot/RUNBOOK.md) before
changing firmware keys, shim, Lanzaboote, the MOK, or EFI boot entries.
