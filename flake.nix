{
  description = "computer-nix: home-manager for ephemeral computer boxes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pin to a specific revision: nvim-config is someone else's repo tracking
    # their master. Without a rev pin, a force-push or delete breaks every
    # fresh box build. Bump this deliberately via `nix flake update nvim-config`.
    nvim-config = {
      url = "github:harivansh-afk/nix/987df46386f2449262a2c2699492e0a4d6c5b12f";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
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

      # Single source of truth for the nixpkgs configuration. Used both by
      # forAllSystems (for per-system outputs) and by the home-manager
      # configuration below — no more duplicated `import nixpkgs { ... }`.
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f (mkPkgs system));

      username = "node";

      # Every current computer box is x86_64-linux. If an arm64 box shows up,
      # add `homeConfigurations.computer-aarch64 = ...` rather than flipping
      # this — scripts/bootstrap.sh should pick by arch.
      hmSystem = "x86_64-linux";
    in
    {
      homeConfigurations.computer = home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs hmSystem;
        extraSpecialArgs = { inherit inputs username; };
        modules = [ ./home ];
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      # Each script in scripts/ packaged as a shellcheck'd writeShellApplication.
      # Exposed as a flake output for CI and to be pulled into the devshell.
      packages = forAllSystems (pkgs: import ./scripts { inherit pkgs; });

      # Real build gates, not just eval:
      #   * `activation` builds the home-manager activation package, which
      #     instantiates every module and catches errors `flake check` alone
      #     misses (template interpolations, shell string escapes, etc.).
      #   * `scripts` links every packaged script, forcing shellcheck to run
      #     at check time rather than only when someone happens to `nix build`.
      checks = forAllSystems (
        pkgs:
        nixpkgs.lib.optionalAttrs (pkgs.system == hmSystem) {
          activation = self.homeConfigurations.computer.activationPackage;
        }
        // {
          scripts = pkgs.linkFarm "scripts" (
            nixpkgs.lib.mapAttrsToList (name: path: { inherit name path; }) self.packages.${pkgs.system}
          );
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            just
            jq
            fzf
            gum
            shellcheck
            nixfmt-tree
          ];
          shellHook = ''
            echo "computer-nix dev shell — 'just' to see recipes"
          '';
        };

        neovim = import ./shells/neovim.nix { inherit pkgs; };

        tmux = import ./shells/tmux.nix { inherit pkgs; };
      });
    };
}
