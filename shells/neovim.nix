# Dev shell for hacking on Neovim from a source checkout.
#
# Neovim upstream removed its in-repo flake in neovim#28863 ("we don't plan on
# maintaining these anymore"), pointing users at nix-community/neovim-nightly-
# overlay. That overlay is great for running nightly, but it doesn't give you a
# "drop into a shell, `cmake --build build`, hack, repeat" loop against an
# arbitrary checkout. This shell fills that gap.
#
# We inherit buildInputs/nativeBuildInputs from nixpkgs' own `neovim-unwrapped`
# derivation via `inputsFrom`, which means the package set never drifts:
# bumping `nixpkgs-unstable` bumps libuv / luajit / tree-sitter / etc. for free.
# On top of that we layer the dev-only tooling the in-tree CMake targets
# expect (stylua, ts_query_ls, lua-language-server, luacheck, shellcheck,
# uncrustify, clangd).
#
# Usage from a neovim checkout:
#   nix develop github:getcompanion-ai/computer-nix#neovim
#   cmake -S cmake.deps -B .deps -G Ninja
#   cmake --build .deps
#   cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
#   cmake --build build
{ pkgs }:
pkgs.mkShell {
  inputsFrom = [ pkgs.neovim-unwrapped ];

  packages = with pkgs; [
    ccache
    clang-tools
    git
    lua-language-server
    ninja
    shellcheck
    stylua
    ts_query_ls
    uncrustify

    luajitPackages.luacheck

    python3Packages.pynvim
  ];

  env.ASAN_OPTIONS = "log_path=./test.log:abort_on_error=1";
}
