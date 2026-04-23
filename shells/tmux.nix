# Dev shell for hacking on tmux from a source checkout.
#
# tmux uses plain autotools (`sh autogen.sh && ./configure && make`), no
# upstream flake, and no real need for one — its dep graph is small and
# nixpkgs already expresses it well. We reuse that via `inputsFrom`: the
# buildInputs and nativeBuildInputs nixpkgs ships for `pkgs.tmux` are exactly
# what `./configure` expects (ncurses, libevent, utf8proc, libutempter,
# pkg-config, autoreconfHook which pulls autoconf/automake/libtool, bison).
# Bumping `nixpkgs-unstable` bumps that set for free.
#
# The extra tooling layered on top (ccache, clangd, gdb) is what's actually
# useful when editing tmux — no lint/format toolchain like neovim has.
#
# Usage from a tmux checkout:
#   nix develop github:getcompanion-ai/computer-nix#tmux
#   sh autogen.sh
#   mkdir -p build && cd build
#   ../configure --enable-utf8proc --enable-utempter
#   make -j
{ pkgs }:
pkgs.mkShell {
  inputsFrom = [ pkgs.tmux ];

  packages = with pkgs; [
    ccache
    clang-tools
    gdb
    git
  ];
}
