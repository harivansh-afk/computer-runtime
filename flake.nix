{
  description = "computer-nix: home-manager for ephemeral computer boxes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvim-config = {
      url = "github:harivansh-afk/nix";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      # The real home-manager target is Linux, but we want `nix flake check` /
      # `nix fmt` / `nix develop` to also work from a darwin laptop (where the
      # orchestrator is actually run). forAllSystems covers both.
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f (import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }));

      username = "node";
      hmPkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations.computer = home-manager.lib.homeManagerConfiguration {
        pkgs = hmPkgs;
        extraSpecialArgs = { inherit inputs username; };
        modules = [ ./home ];
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      # Each script in scripts/ packaged as a shellcheck'd writeShellApplication.
      # Exposed as a flake output for CI and to be pulled into the devshell.
      packages = forAllSystems (pkgs: import ./scripts { inherit pkgs; });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            just
            jq
            fzf
            gum
            shellcheck
            nixfmt
          ];
          shellHook = ''
            echo "computer-nix dev shell — 'just' to see recipes"
          '';
        };
      });
    };
}
