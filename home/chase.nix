{ pkgs, ... }:

{
	home = {
		username = "chase";
		homeDirectory = "/home/chase";

# Existing user-facing packages migrated from environment.systemPackages.
		packages = with pkgs; [
			codex
				ghostty
				grim
				hypridle
				hyprlauncher
				hyprlock
				hyprpaper
				kdePackages.dolphin
				kitty
				mako
				neovim
				pavucontrol
				rofi
				slurp
				vivaldi
				waybar
				wget
				wl-clipboard
				bitwarden-desktop
				github-cli
				];

# Keep this at the first Home Manager version used for this account.
		stateVersion = "26.05";
	};

	programs = {
		git = {
			enable = true;
			lfs.enable = true;
			settings.user = {
				name = "Chase Haley";
				email = "chasehaley33@gmail.com";
			};
		};
		home-manager.enable = true;
	};
}
