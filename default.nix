{ stdenv, lib, fetchFromGitLab, rustPlatform }:

rustPlatform.buildRustPackage rec {
  name = "shelfie-${version}";
  version = "0.1.0";

  src = fetchFromGitLab {
    owner = "spacekookie";
    repo = "shelfie";
    rev = version;
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };

  cargoSha256 = "0000000000000000000000000000000000000000000000000000";

  meta = with lib; {
    description = "A small space to upload pictures to";
    license = licenses.agpl;
    maintainers = [ maintainers.spacekookie ];
    platforms = platforms.all;
  };
}
