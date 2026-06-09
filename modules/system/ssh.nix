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
        Whether to optimize for connecting to hardened SSH.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.server.hardening.enable {
      # Rate limiting SSH requests blocks brute force hacks.
      # See <https://debian-administration.org/article/187/Using_iptables_to_rate-limit_incoming_connections>.
      # `--hitcount n+1` allows n connections before rejecting.
      # Subsequent connections
      # within `--seconds` time
      # are rejected
      # and reset the timer.
      networking.firewall.extraCommands = ''
        ${lib.concatStringsSep "\n" (
          map (port: ''
            iptables -I nixos-fw -p tcp --dport ${toString port} -m state --state NEW -m recent --name ssh-rate-limit --set
            iptables -I nixos-fw -p tcp --dport ${toString port} -m state --state NEW -m recent --name ssh-rate-limit --update --seconds 60 --hitcount 4 -j nixos-fw-log-refuse
          '') config.services.openssh.ports
        )}
      '';

      # Certificate authentication is common
      # and more secure.
      services.openssh.settings = {
        KbdInteractiveAuthentication = lib.mkDefault false;
        PasswordAuthentication = lib.mkDefault false;
      };
    })
    (lib.mkIf cfg.client.optimization.enable {
      # With rate limiting,
      # reusing connections is necessary for some use cases.
      programs.ssh.extraConfig = ''
        Host *
        ControlMaster auto
        ControlPath ~/.ssh/%r@%h:%p
      '';
    })
  ];
}
