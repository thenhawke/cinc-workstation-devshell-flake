source $stdenv/setup
PATH=$dpkg/bin:$PATH

dpkg -x $src unpacked

cp -r unpacked/* $out/

# Patch ELF files to use the Nix dynamic linker and set the rpath to the embedded lib directory
for bin in $out/cinc-workstation/embedded/bin/*; do 
  if ! file $bin | grep -q ELF; then continue; fi
  patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "$rpath:$out/cinc-workstation/embedded/lib" \
      $bin
done

cat > $out/cinc-workstation/bin/cw-wrapper <<EOF
#!$SHELL
/opt/cinc-workstation/bin/"\$@"
EOF
chmod +x $out/cinc-workstation/bin/cw-wrapper

