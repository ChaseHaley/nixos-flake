{
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user = {
        name = "Chase Haley";
        email = "chasehaley33@gmail.com";
      };

      init.defaultBranch = "main";
    };
  };
}
