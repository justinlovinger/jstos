pkgs:
pkgs.buildNpmPackage rec {
  pname = "kagi-ken-mcp";
  version = "1.3.0";

  src = pkgs.fetchFromGitHub {
    owner = "czottmann";
    repo = pname;
    tag = "${version}";
    hash = "sha256-ruQdeOKKqfrYh2CgnUujEmw2LsmhU6E+INmy81oI8t0=";
  };
  npmDepsHash = "sha256-Nj2pzjN8K9TbYluGaDnlLYbxxSeE8qtMGvaXdZLXnvk=";

  makeCacheWritable = true;

  dontNpmBuild = true;

  meta.mainProgram = pname;
}
