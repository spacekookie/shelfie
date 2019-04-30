{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.shelfie;
in
  {
    options = {
      services.shelfie = {
        enable = mkEnableOption "shelfie";

        package = mkOption {
          type = types.path;
          default = pkgs.shelfie;
          description = "Path to the shelfie sources";
        };

        port = mkOption {
          type = types.integer;
          default = 12220;
          description = "The port to bind the (internal) shelfie server to";
        };

        dataDir = mkOption {
          type = types.str;
          default = "/var/lib/shelfie";
          description = "The directory in which to keep uploaded data";
        };

        autoScrub = mkOption {
            type = types.hash;
            default = {};
            description = "Specify auto-scrub behaviour automatically invoked";
        };
      };
    };

    config = mkIf cfg.enable {

    };
}