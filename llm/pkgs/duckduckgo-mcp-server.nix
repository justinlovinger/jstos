pkgs:
pkgs.python3Packages.buildPythonApplication rec {
  pname = "duckduckgo-mcp-server";
  version = "0.1.1";
  pyproject = true;

  # Newer Nixpkgs can use `inherit (finalAttrs) pname version;`.
  src = pkgs.fetchPypi {
    inherit version;
    pname = builtins.replaceStrings [ "-" ] [ "_" ] pname;
    hash = "sha256-1vSPTLQjTennFuh/fUmqVGN+vEo3AOz9BfJgaWRjwOw=";
  };

  build-system = with pkgs.python3Packages; [ hatchling ];

  dependencies = with pkgs.python3Packages; [
    beautifulsoup4
    httpx
    mcp
  ];

  meta.mainProgram = pname;
}
