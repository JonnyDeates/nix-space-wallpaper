# Home Manager module: runs the space wallpaper on each listed monitor as a systemd user service
# (space-wallpaper@<output>), all under space-wallpaper.target, plus the Hyprland pauser.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.space-wallpaper;
  hyprlandPackage = config.wayland.windowManager.hyprland.package or null;
  finalPackage = cfg.package.override (
    {
      inherit (cfg) fps scenePeriod plainSkyShare;
      previewOutput = cfg.preview.output;
      withPauser = cfg.pauser.enable;
    }
    // lib.optionalAttrs (hyprlandPackage != null) { hyprland = hyprlandPackage; }
  );
  instance = mon: "space-wallpaper@${mon}.service";
  # Keep retrying instead of hitting systemd's start limit while the compositor is down.
  resilient = {
    Restart = "always";
    RestartSec = 2;
  };
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
      default = config.wayland.windowManager.hyprland.enable or false;
      defaultText = lib.literalExpression "config.wayland.windowManager.hyprland.enable";
      description = ''
        Freeze a monitor's wallpaper while a window is open on it, so it uses no GPU while you work.
        Hyprland only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ finalPackage ];

    systemd.user.targets.space-wallpaper = {
      Unit = {
        Description = "Animated space wallpaper";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        Wants = map instance cfg.monitors ++ lib.optional cfg.pauser.enable "space-wallpaper-pauser.service";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services."space-wallpaper@" = {
      Unit = {
        Description = "Animated space wallpaper on %i";
        PartOf = [ "space-wallpaper.target" ];
        After = [ "graphical-session.target" ];
        StartLimitIntervalSec = 0;
      };
      Service =
        resilient
        // {
          ExecStart = "${finalPackage}/bin/space-wallpaper-launch %i";
        }
        // lib.optionalAttrs (cfg.seed != null) {
          Environment = "SPACE_WALLPAPER_SEED=${toString cfg.seed}";
        };
    };

    systemd.user.services.space-wallpaper-pauser = lib.mkIf cfg.pauser.enable {
      Unit = {
        Description = "Pause the space wallpaper behind open windows";
        PartOf = [ "space-wallpaper.target" ];
        After = [ "graphical-session.target" ];
        StartLimitIntervalSec = 0;
      };
      Service = resilient // {
        ExecStart = "${finalPackage}/bin/space-wallpaper-pauser";
      };
    };
  };
}
