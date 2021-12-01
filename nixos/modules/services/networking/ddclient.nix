{ config, pkgs, lib, ... }:

let
  cfg = config.services.ddclient;
  boolToStr = bool: if bool then "yes" else "no";
  dataDir = "/var/lib/ddclient";
  StateDirectory = builtins.baseNameOf dataDir;
  RuntimeDirectory = StateDirectory;

  configFile' = pkgs.writeText "ddclient.conf" ''
    # This file can be used as a template for configFile or is automatically generated by Nix options.
    cache=${dataDir}/ddclient.cache
    foreground=YES
    use=${cfg.use}
    login=${cfg.username}
    password=
    protocol=${cfg.protocol}
    ${lib.optionalString (cfg.script != "") "script=${cfg.script}"}
    ${lib.optionalString (cfg.server != "") "server=${cfg.server}"}
    ${lib.optionalString (cfg.zone != "")   "zone=${cfg.zone}"}
    ssl=${boolToStr cfg.ssl}
    wildcard=YES
    ipv6=${boolToStr cfg.ipv6}
    quiet=${boolToStr cfg.quiet}
    verbose=${boolToStr cfg.verbose}
    ${cfg.extraConfig}
    ${lib.concatStringsSep "," cfg.domains}
  '';
  configFile = if (cfg.configFile != null) then cfg.configFile else configFile';

  preStart = ''
    install --mode=0400 ${configFile} /run/${RuntimeDirectory}/ddclient.conf
    ${lib.optionalString (cfg.configFile == null) (if (cfg.passwordFile != null) then ''
      password=$(head -n 1 ${cfg.passwordFile})
      sed -i "s/^password=$/password=$password/" /run/${RuntimeDirectory}/ddclient.conf
    '' else ''
      sed -i '/^password=$/d' /run/${RuntimeDirectory}/ddclient.conf
    '')}
  '';

in

with lib;

{

  imports = [
    (mkChangedOptionModule [ "services" "ddclient" "domain" ] [ "services" "ddclient" "domains" ]
      (config:
        let value = getAttrFromPath [ "services" "ddclient" "domain" ] config;
        in if value != "" then [ value ] else []))
    (mkRemovedOptionModule [ "services" "ddclient" "homeDir" ] "")
    (mkRemovedOptionModule [ "services" "ddclient" "password" ] "Use services.ddclient.passwordFile instead.")
  ];

  ###### interface

  options = {

    services.ddclient = with lib.types; {

      enable = mkOption {
        default = false;
        type = bool;
        description = ''
          Whether to synchronise your machine's IP address with a dynamic DNS provider (e.g. dyndns.org).
        '';
      };

      package = mkOption {
        type = package;
        default = pkgs.ddclient;
        defaultText = "pkgs.ddclient";
        description = ''
          The ddclient executable package run by the service.
        '';
      };

      domains = mkOption {
        default = [ "" ];
        type = listOf str;
        description = ''
          Domain name(s) to synchronize.
        '';
      };

      username = mkOption {
        default = "";
        type = str;
        description = ''
          User name.
        '';
      };

      passwordFile = mkOption {
        default = null;
        type = nullOr str;
        description = ''
          A file containing the password.
        '';
      };

      interval = mkOption {
        default = "10min";
        type = str;
        description = ''
          The interval at which to run the check and update.
          See <command>man 7 systemd.time</command> for the format.
        '';
      };

      configFile = mkOption {
        default = null;
        type = nullOr path;
        description = ''
          Path to configuration file.
          When set this overrides the generated configuration from module options.
        '';
        example = "/root/nixos/secrets/ddclient.conf";
      };

      protocol = mkOption {
        default = "dyndns2";
        type = str;
        description = ''
          Protocol to use with dynamic DNS provider (see https://sourceforge.net/p/ddclient/wiki/protocols).
        '';
      };

      server = mkOption {
        default = "";
        type = str;
        description = ''
          Server address.
        '';
      };

      ssl = mkOption {
        default = true;
        type = bool;
        description = ''
          Whether to use SSL/TLS to connect to dynamic DNS provider.
        '';
      };

      ipv6 = mkOption {
        default = false;
        type = bool;
        description = ''
          Whether to use IPv6.
        '';
      };


      quiet = mkOption {
        default = false;
        type = bool;
        description = ''
          Print no messages for unnecessary updates.
        '';
      };

      script = mkOption {
        default = "";
        type = str;
        description = ''
          script as required by some providers.
        '';
      };

      use = mkOption {
        default = "web, web=checkip.dyndns.com/, web-skip='Current IP Address: '";
        type = str;
        description = ''
          Method to determine the IP address to send to the dynamic DNS provider.
        '';
      };

      verbose = mkOption {
        default = true;
        type = bool;
        description = ''
          Print verbose information.
        '';
      };

      zone = mkOption {
        default = "";
        type = str;
        description = ''
          zone as required by some providers.
        '';
      };

      extraConfig = mkOption {
        default = "";
        type = lines;
        description = ''
          Extra configuration. Contents will be added verbatim to the configuration file.
        '';
      };
    };
  };


  ###### implementation

  config = mkIf config.services.ddclient.enable {
    systemd.services.ddclient = {
      description = "Dynamic DNS Client";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartTriggers = optional (cfg.configFile != null) cfg.configFile;

      serviceConfig = {
        DynamicUser = true;
        RuntimeDirectoryMode = "0700";
        inherit RuntimeDirectory;
        inherit StateDirectory;
        Type = "oneshot";
        ExecStartPre = "!${pkgs.writeShellScript "ddclient-prestart" preStart}";
        ExecStart = "${lib.getBin cfg.package}/bin/ddclient -file /run/${RuntimeDirectory}/ddclient.conf";
      };
    };

    systemd.timers.ddclient = {
      description = "Run ddclient";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.interval;
        OnUnitInactiveSec = cfg.interval;
      };
    };
  };
}
