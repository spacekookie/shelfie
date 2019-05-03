{ stdenv, lib, fetchFromGitLab, rustPlatform }:

rustPlatform.buildRustPackage rec {
  name = "shelfie-${version}";
  version = "0.1.0";

  src = ./.;

  cargoSha256 = "06nhwxyv2x78gdky5lz9raipx6z764n9ffqwq30x4mfxbsbdwf2x";

  meta = with lib; {
    description = "A small space to upload pictures to";
    license = licenses.agpl3;
    maintainers = [ maintainers.spacekookie ];
    platforms = platforms.all;
  };
}
