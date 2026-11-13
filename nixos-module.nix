# NixOS module (no Home Manager needed): installs the package and its systemd user units, and starts
# the wallpaper on the listed monitors with every user's graphical session.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.space-wallpaper;
  finalPackage = cfg.package.override (
    {
      inherit (cfg) fps scenePeriod plainSkyShare;
      previewOutput = cfg.preview.output;
      withPauser = cfg.pauser.enable;
    }
    // lib.optionalAttrs config.programs.hyprland.enable {
      hyprland = config.programs.hyprland.package;
    }
  );
in
{
  options.services.space-wallpaper = {
    enable = lib.mkEnableOption "the animated space wallpaper";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "The space-wallpaper package. The options below are applied to it with `.override`.";
    };

    monitors = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      example = [
        "DP-1"
        "HDMI-A-1"
      ];
      description = "Outputs to draw the wallpaper on (names as `hyprctl monitors` or `wlr-randr` show them).";
    };

    fps = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20;
      description = "Frames per second. Everything moves slowly, so more mostly costs GPU.";
    };

    scenePeriod = lib.mkOption {
      type = lib.types.ints.between 120 86400;
      default = 1800;
      description = "Seconds each scene lasts before the next one is rolled.";
    };

    plainSkyShare = lib.mkOption {
      type = lib.types.numbers.between 0 1;
      default = 0.25;
      description = "Share of scene slots that show just the plain sky.";
    };

    seed = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 0 99999);
      default = null;
      description = ''
        Fixed seed for which scenes roll and how they look. `null` picks a random one each launch
        (logged in the journal, so one you liked can be set here).
      '';
    };

    preview.output = lib.mkOption {
      type = lib.types.str;
      default = builtins.head cfg.monitors;
      defaultText = lib.literalExpression "builtins.head config.services.space-wallpaper.monitors";
      description = "Output `space-wallpaper-preview` draws on when none is given.";
    };

    pauser.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.programs.hyprland.enable;
      defaultText = lib.literalExpression "config.programs.hyprland.enable";
      description = ''
        Freeze a monitor's wallpaper while a window is open on it, so it uses no GPU while you work.
        Hyprland only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ finalPackage ];
    # The units come from the package (lib/systemd/user); these add to them.
    systemd.packages = [ finalPackage ];

    systemd.user.targets.space-wallpaper = {
      wantedBy = [ "graphical-session.target" ];
      wants = map (mon: "space-wallpaper@${mon}.service") cfg.monitors;
    };

    systemd.user.services."space-wallpaper@" = lib.mkIf (cfg.seed != null) {
      environment.SPACE_WALLPAPER_SEED = toString cfg.seed;
    };
  };
}
