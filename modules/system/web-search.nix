{
  config,
  lib,
  ...
}:
let
  cfg = config.jstos.system.webSearch;
in
{
  options.jstos.system.webSearch = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.jstos.enable && config.jstos.device.has.regularUsage;
      defaultText = lib.literalExpression "config.jstos.enable && config.jstos.device.has.regularUsage";
      description = ''
        Whether to enable a local web search engine.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.searx = {
      enable = true;

      # The secret key being public is ok as long as the instance is only reachable locally.
      settings.server.secret_key = lib.mkDefault "de4e95b54951d2abab2d717ed34d0f44b27545a3b741da5abae269ca10ae4d54";

      # This should already be the default,
      # but we want to be extra sure given the key is public.
      openFirewall = false;

      # The address and port are defaults,
      # but we set them so we can reference them.
      # Note,
      # setting `base_url` to `let searxServer = config.services.searx.settings.server; in "http://${searxServer.bind_address}:${searxServer.port}";`
      # results in infinite recursion.
      settings.server = {
        base_url = lib.mkDefault "http://127.0.0.1:8888";
        bind_address = lib.mkDefault "127.0.0.1";
        port = lib.mkDefault "8888";
      };

      settings.ui = {
        theme_args.simple_style = lib.mkDefault "black";
        hotkeys = lib.mkDefault "vim";
      };

    };
  };
}
