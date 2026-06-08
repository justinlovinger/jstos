{
  config,
  lib,
  ...
}:
let
  cfg = config.jstos.system.ssh;
in
{
  options.jstos.system.ssh = {
    server.hardening.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.jstos.enable;
      defaultText = lib.literalExpression "config.jstos.enable";
      description = ''
        Whether to harden SSH security.
      '';
    };
    client.optimization.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.jstos.enable && config.jstos.device.has.regularUsage;
      defaultText = lib.literalExpression "config.jstos.enable && config.jstos.device.has.regularUsage";
      description = ''
        Whether to improve SSH performance.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.server.hardening.enable {
      # The `linux` collection includes rules for SSH.
      services.crowdsec = {
        enable = true;
        hub.collections = [ "crowdsecurity/linux" ];
      };
      # CrowdSec is too verbose by default,
      # but there is currently no easy way to change the log level,
      # see <https://github.com/NixOS/nixpkgs/pull/446307#pullrequestreview-4451542997>.
      systemd.services.crowdsec.serviceConfig.ExecStart =
        lib.mkForce "${lib.getExe' config.services.crowdsec.package "crowdsec"} -warning";
      services.crowdsec-firewall-bouncer = {
        enable = true;
        # The firewall bouncer is not as verbose as CrowdSec,
        # but it is still verbose enough
        # that identifying issues among the noise
        # can be difficult.
        settings.log_level = "warn";
      };
      # The service may timeout on slower machines.
      systemd.services.crowdsec.serviceConfig.TimeoutStartSec = "infinity";

      # Certificate authentication is common
      # and more secure.
      services.openssh.settings = {
        KbdInteractiveAuthentication = lib.mkDefault false;
        PasswordAuthentication = lib.mkDefault false;
      };
    })
    (lib.mkIf cfg.client.optimization.enable {
      # Reusing connections is more efficient.
      programs.ssh.extraConfig = ''
        Host *
        ControlMaster auto
        ControlPath ~/.ssh/%r@%h:%p
      '';
    })
  ];
}
