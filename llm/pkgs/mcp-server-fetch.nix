pkgs:
pkgs.python3Packages.buildPythonApplication rec {
  pname = "mcp-server-fetch";
  version = "2025.4.7";
  pyproject = true;

  # Newer Nixpkgs can use `inherit (finalAttrs) pname version;`.
  src = pkgs.fetchPypi {
    inherit version;
    pname = builtins.replaceStrings [ "-" ] [ "_" ] pname;
    hash = "sha256-VieePFXLHlBrlYypuyPtRBOUSm8jC8oh4ESu5Rc0/kc=";
  };

  # See <https://github.com/modelcontextprotocol/servers/issues/1146>
  # and <https://github.com/modelcontextprotocol/servers/pull/3293>.
  # The below patch is derived from the above pull request.
  patches = [
    (builtins.toFile "fix-httpx.patch" ''
      From 8614dff06ff6cb0eee75af36674f1e19f035cabc Mon Sep 17 00:00:00 2001
      From: thecaptain789 <thecaptain789@users.noreply.github.com>
      Date: Fri, 6 Feb 2026 15:25:43 +0000
      Subject: [PATCH] fix(fetch): update to httpx 0.28+ proxy parameter

      The httpx library renamed 'proxies' to 'proxy' in version 0.28.0.
      This updates the fetch server to use the new parameter name and
      removes the version cap on httpx.

      Fixes #3287
      ---
       pyproject.toml                 | 2 +-
       src/mcp_server_fetch/server.py | 4 ++--
       tests/test_server.py           | 2 +-
       3 files changed, 4 insertions(+), 4 deletions(-)

      diff --git a/pyproject.toml b/pyproject.toml
      index 24b42d8e3e..e2d0d38d0c 100644
      --- a/pyproject.toml
      +++ b/pyproject.toml
      @@ -16,7 +16,7 @@ classifiers = [
           "Programming Language :: Python :: 3.10",
       ]
       dependencies = [
      -    "httpx<0.28",
      +    "httpx>=0.27",
           "markdownify>=0.13.1",
           "mcp>=1.1.3",
           "protego>=0.3.1",
      diff --git a/src/mcp_server_fetch/server.py b/src/mcp_server_fetch/server.py
      index 2df9d3b604..d128987351 100644
      --- a/src/mcp_server_fetch/server.py
      +++ b/src/mcp_server_fetch/server.py
      @@ -72,7 +72,7 @@ async def check_may_autonomously_fetch_url(url: str, user_agent: str, proxy_url:

           robot_txt_url = get_robots_txt_url(url)

      -    async with AsyncClient(proxies=proxy_url) as client:
      +    async with AsyncClient(proxy=proxy_url) as client:
               try:
                   response = await client.get(
                       robot_txt_url,
      @@ -116,7 +116,7 @@ async def fetch_url(
           """
           from httpx import AsyncClient, HTTPError

      -    async with AsyncClient(proxies=proxy_url) as client:
      +    async with AsyncClient(proxy=proxy_url) as client:
               try:
                   response = await client.get(
                       url,
    '')
  ];

  build-system = with pkgs.python3Packages; [ hatchling ];

  dependencies =
    with pkgs.python3Packages;
    [
      httpx
      markdownify
      mcp
      protego
      pydantic
      readabilipy
      requests
    ]
    ++ [ pkgs.nodejs ];

  meta.mainProgram = pname;
}
