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
          type = types.int;
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

        user = mkOption {
          type = types.str;
          default = "shelfie";
          description = ''
            User under which shelfie runs
            If it is set to "shelfie", a user will be created.
          '';
        };

        group = mkOption {
          type = types.str;
          default = "shelfie";
          description = ''
            Group under which shelfie runs
            If it is set to "shelfie", a group will be created.
          '';
        };

        configureNginx = mkEnableOption "Configure nginx as reverse proxy for shelfie";

        appDomain = mkOption {
          description = "Domain used to serve shelfie";
          type = types.str;
          example = "img.example.org";
        };

        uploadBasicAuthFile = mkOption {
          description = ''
            Basic Auth password file for the shelfie upload endpoint
          '';
          type = types.nullOr types.path;
          default = null;
        };

      };
    };

    config = mkIf cfg.enable {

      systemd.services.shelfie-init = {
        script = ''
          mkdir -p ${cfg.dataDir}
          chown ${cfg.user}:${cfg.group} ${cfg.dataDir}
        '';
        serviceConfig = {
          Type = "oneshot";
        };
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
      };

      systemd.services.shelfie = {
        serviceConfig = {
          ExecStart = "${cfg.package}/bin/shelfie";
          Restart = "always";
          RestartSec = "20s";
          User = cfg.user;
          Group = cfg.group;
        };
        after = [ "shelfie-init.service" "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment.SHELFIE_PORT = toString(cfg.port);
        environment.SHELFIE_STORAGE = cfg.dataDir;
      };

      services.nginx = lib.mkIf cfg.configureNginx {
        enable = true;
        virtualHosts."${cfg.appDomain}" = {
          locations."/".proxyPass = "http://127.0.0.1:${toString(cfg.port)}/";
          locations."/upload/".extraConfig = optionalString (cfg.uploadBasicAuthFile != null) ''
            auth_basic secured;
            auth_basic_user_file ${cfg.uploadBasicAuthFile};
          '';
        };
      };

      users.users.shelfie = mkIf (cfg.user == "shelfie") {
        isSystemUser = true;
        inherit (cfg) group;
      };

      users.groups.shelfie = mkIf (cfg.group == "shelfie") { };

    };
  }
