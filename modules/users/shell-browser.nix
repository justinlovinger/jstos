{
  config,
  lib,
  ...
}:
let
  config' = config;

  cfgs = map (jstos: jstos.shellBrowser) (builtins.attrValues config.jstos.users);
in
{
  jstos.userModules = [
    (
      { config, ... }:
      {
        options.shellBrowser = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.enable && config'.jstos.device.has.regularUsage;
            defaultText = lib.literalExpression "config.jstos.users.<name>.enable && config.jstos.device.has.regularUsage";
            description = ''
              Whether to enable the shell browser.
            '';
          };

          webSearch = lib.mkOption {
            type = lib.types.enum [
              "paid"
              "system"
              "direct"
            ];
            default = config.webSearch;
            defaultText = lib.literalExpression "config.jstos.users.<name>.webSearch";
            description = ''
              See `config.jstos.users.<name>.webSearch`.
              `paid` requires signing in,
              which may require a Session Link.
            '';
          };
        };
      }
    )
  ];

  jstos.system.webSearch.enable = lib.mkIf (lib.any (
    cfg: cfg.enable && cfg.webSearch == "system"
  ) cfgs) true;

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.shellBrowser;

      kagiSearch = "https://kagi.com/html/search?q=";
      searxngSearch = "${config'.services.searx.settings.server.base_url}/search?q=";
    in
    lib.mkIf cfg.enable {
      programs.chawan = {
        enable = true;
        settings = {
          buffer = {
            scripting = "app";
            cookie = true;
          };
          display.color-mode = "true-color";
          siteconf.kagi = lib.mkIf (cfg.webSearch == "paid") {
            host = "(.*\.)?kagi\.com";
            cookie = "save";
            share-cookie-jar = "kagi.com";
          };
          omnirule =
            let
              searchTerms = ''encodeURIComponent(x.split(":").slice(1).join(":"))'';
            in
            {
              kagi = lib.mkIf (jstos.webSearch == "paid") {
                match = "^kg";
                substitute-url = ''(x) => "${kagiSearch}" + ${searchTerms}'';
              };
              searxng = lib.mkIf config'.jstos.system.webSearch.enable {
                name = "^sx";
                substitute-url = ''(x) => "${searxngSearch}" + ${searchTerms}'';
              };
            };
          # Note,
          # I could not get `cmd.buffer.CMD` working.
          page = {
            q = "";
            Q = "() => quit()";

            h = "n => pager.scrollLeft(n)";
            j = "n => pager.scrollDown(n)";
            k = "n => pager.scrollUp(n)";
            l = "n => pager.scrollRight(n)";

            u = "n => pager.halfPageUp(n)";
            d = "n => pager.halfPageDown(n)";

            H = "n => pager.cursorLeft(n)";
            J = "n => pager.cursorDown(n)";
            K = "n => pager.cursorUp(n)";
            L = "n => pager.cursorRight(n)";

            # `C-k` is the keybinding for web search.
            C-k = lib.mkDefault ''() => pager.load("${
              if jstos.webSearch == "paid" then
                "kg"
              else if jstos.webSearch == "system" then
                "sx"
              else
                "ddg"
            }:")'';
          };
        };
      };

      programs.nushell.extraConfig =
        let
          searchUrl =
            if cfg.webSearch == "paid" then
              kagiSearch
            else if cfg.webSearch == "system" then
              searxngSearch
            else
              "https://lite.duckduckgo.com/lite?kp=-1&kd=-1&q=";
        in
        lib.mkIf jstos.shell.enable ''
          def ? [...query: string] {
            cha $"${searchUrl}($query | str join ' ' | url encode --all)"
          }
        '';
    }
  ) config.jstos.users;
}
