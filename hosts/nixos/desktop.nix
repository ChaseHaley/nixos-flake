{ ... }:

{
  services.xserver = {
    xkb = {
      layout = "us";
      variant = "";
    };
    videoDrivers = [ "nvidia" ];
  };

  programs.dms-greeter = {
    enable = true;
    compositor.name = "hyprland";
    configHome = "/home/chase";
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
    };
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.steam = {
    enable = true;
    protontricks.enable = true;
  };

  programs.gamescope.enable = true;
}
