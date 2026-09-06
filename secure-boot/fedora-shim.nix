{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "fedora-shim-x64";
  version = "16.1-7";

  src = pkgs.fetchurl {
    url = "https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/s/shim-x64-16.1-7.x86_64.rpm";
    hash = "sha256-wrV2iWFvlAWuIrcnuAlKtTOW7qLY0tkln7i7IxNO/TU=";
  };

  nativeBuildInputs = [
    pkgs.cpio
    pkgs.rpm
  ];

  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    mkdir extracted "$out"
    cd extracted
    rpm2cpio "$src" | cpio --extract --make-directories
    efi=usr/lib/efi/shim/16.1-7/EFI
    install -Dm0644 "$efi/fedora/shimx64.efi" "$out/shimx64.efi"
    install -Dm0644 "$efi/fedora/mmx64.efi" "$out/mmx64.efi"
    install -Dm0644 "$efi/BOOT/fbx64.efi" "$out/fbx64.efi"
    runHook postInstall
  '';

  meta = {
    description = "Fedora 16.1 Microsoft-signed x64 shim EFI binaries";
    homepage = "https://packages.fedoraproject.org/pkgs/shim/shim-x64/";
    license = pkgs.lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
