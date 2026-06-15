{
  pkgs,
  ...
}:
pkgs.buildNpmPackage rec {
  pname = "open-websearch";
  version = "2.1.9";

  src = pkgs.fetchFromGitHub {
    owner = "Aas-ee";
    repo = "open-webSearch";
    tag = "v${version}";
    hash = "sha256-ZS56Eoy9IePLeyopv4AK6FU8+b1E8r/WPK6RYDvy6yA=";
  };

  npmDepsHash = "sha256-Ua20YOYr/D06eMQsgBgfN/W7F74wfjjHXL10XIB0nFA=";

  meta.mainProgram = pname;
}
