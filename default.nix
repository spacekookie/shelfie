{ sources ? import ./nix/sources.nix
, pkgs ? import sources.nixpkgs {}
, shelfieSrc ? fetchGit ./. }:

let
  naersk = pkgs.callPackage sources.naersk {};
in
  (naersk.buildPackage shelfieSrc) // {
    meta = with pkgs.lib; {
      description = "A small space to upload pictures to";
      license = licenses.agpl3;
      maintainers = [ maintainers.spacekookie ];
      platforms = platforms.all;
    };
  }
