{
  programs.ssh = {
    enable = true;
    # Opt out of home-manager's legacy default-config block; we manage our own
    # defaults via matchBlocks."*" to silence the deprecation warning.
    enableDefaultConfig = false;
    matchBlocks."*" = {
      compression = true;
      serverAliveInterval = 30;
      serverAliveCountMax = 3;
      controlMaster = "auto";
      controlPath = "~/.ssh/cm-%r@%h:%p";
      controlPersist = "10m";
    };
  };
}
