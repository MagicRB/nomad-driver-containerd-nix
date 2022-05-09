{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-21.11";

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems' = nixpkgs.lib.genAttrs;
      forAllSystems = forAllSystems' supportedSystems;
      pkgsForSystem = system:
        import nixpkgs
          { inherit system;
            overlays = [ self.overlay ];
          };
    in
      {
        packages = forAllSystems (
          system:
          let pkgs = pkgsForSystem system;
          in
            { default = pkgs.nomad-driver-containerd-nix;
            }
        );
        
        overlay = final: prev:
          {
            nomad-driver-containerd-nix = prev.buildGoModule
              { src = ./.;
                pname = "nomad-driver-containerd-nix";
                version = "latest";
                vendorSha256 = "sha256-aKA15Qx4pDoPo4u4AOpQITyhKP/iUvWecg/IDpV6KgA=";
              };
          };
      };
}
