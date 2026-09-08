{ pkgs }:

let
  program = pkgs.writeShellApplication {
    name = "create-shim-mok";
    runtimeInputs = [ pkgs.openssl ];
    text = ''
      set -o noclobber

      if [[ "$(id -u)" -ne 0 ]]; then
        echo "Run this command as root." >&2
        exit 1
      fi

      key_dir=/var/lib/shim-mok/keys/db
      if [[ -e "$key_dir/db.key" || -e "$key_dir/db.pem" || -e "$key_dir/db.der" ]]; then
        echo "Refusing to replace an existing shim MOK in $key_dir" >&2
        exit 1
      fi

      install -d -m 0700 "$key_dir"
      openssl req -new -x509 -newkey rsa:4096 -sha256 -nodes \
        -subj "/CN=Chase NixOS Shim MOK/" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=codeSigning" \
        -days 3650 \
        -keyout "$key_dir/db.key" \
        -out "$key_dir/db.pem"
      openssl x509 -in "$key_dir/db.pem" -outform DER -out "$key_dir/db.der"
      chmod 0600 "$key_dir/db.key"
      chmod 0644 "$key_dir/db.pem" "$key_dir/db.der"

      echo "Created the signing key and MOK certificate in $key_dir"
      echo "No firmware or MOK variables were changed."
    '';
  };
in
{
  type = "app";
  program = "${program}/bin/create-shim-mok";
  meta.description = "Create the local NixOS signing key for shim MOK enrollment";
}
