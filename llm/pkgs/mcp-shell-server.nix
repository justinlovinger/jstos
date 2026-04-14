pkgs:
pkgs.python3Packages.buildPythonApplication rec {
  pname = "mcp-shell-server";
  version = "1.0.3";
  pyproject = true;

  # Newer Nixpkgs can use `inherit (finalAttrs) pname version;`.
  src = pkgs.fetchPypi {
    inherit version;
    pname = builtins.replaceStrings [ "-" ] [ "_" ] pname;
    hash = "sha256-+Ned+SYhineMF26pgJKpohby82ucEIn+YgfzV4kUj0c=";
  };

  build-system = with pkgs.python3Packages; [ hatchling ];

  dependencies = with pkgs.python3Packages; [ mcp ];
  # `asyncio` is included in Python since version 3.4.
  pythonRemoveDeps = [ "asyncio" ];

  meta.mainProgram = pname;
}
