{
  description = "Animated space wallpaper for Wayland: a GLSL starfield with a new scene every half hour";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        space-wallpaper = pkgs.callPackage ./package.nix { };
        default = space-wallpaper;
      });

      overlays.default = final: prev: {
        space-wallpaper = final.callPackage ./package.nix { };
      };

      homeManagerModules = rec {
        space-wallpaper = ./module.nix;
        default = space-wallpaper;
      };

      nixosModules = rec {
        space-wallpaper = ./nixos-module.nix;
        default = space-wallpaper;
      };

      checks = forAllSystems (pkgs: {
        # The whole shader compiles, wrapped the way shaderbg wraps it (its prologue and main()).
        # Catches GLSL mistakes at build time instead of as a blank wallpaper.
        shader-compiles = pkgs.runCommand "space-wallpaper-shader-compiles" { } ''
          {
            printf '#version 450\nuniform sampler2D iBufferA; uniform sampler2D iBufferB; uniform sampler2D iBufferC; uniform sampler2D iBufferD; uniform vec3 iResolution; uniform float iTime; uniform float iTimeDelta; uniform int iFrame; uniform vec4 iMouse;\n'
            cat ${self.packages.${pkgs.system}.default.shader}
            printf 'out vec4 fragColor; void main() {\n    mainImage(fragColor, gl_FragCoord.xy);\n}\n'
          } > space.frag
          ${pkgs.glslang}/bin/glslangValidator space.frag
          touch $out
        '';
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
