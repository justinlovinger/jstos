{
  pkgs,
  ...
}:
pkgs.buildNpmPackage rec {
  pname = "mcp-searxng";
  version = "1.6.0";

  src = pkgs.fetchFromGitHub {
    owner = "ihor-sokoliuk";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-oBpSAAppLfnPhC3tHoE2X1YAGMyd42fka+xAVFuhjKw=";
  };

  npmDepsHash = "sha256-7z5T8po2ya698J7vqu4pA7c8s85k33sRbOV2tRmGdPo=";

  meta.mainProgram = pname;
}
