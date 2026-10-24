{ pkgs, product, entry, implementation }:
if entry == "printable-binary" then product else
pkgs.symlinkJoin {
  name = "printable-binary-canonical-${implementation}";
  paths = [ product ];
  postBuild = ''
    ln -s ${pkgs.lib.escapeShellArg entry} "$out/bin/printable-binary"
  '';
  meta = product.meta // { mainProgram = "printable-binary"; };
  passthru.implementationProduct = product;
}
