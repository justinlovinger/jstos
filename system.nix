{
  config,
  lib,
  ...
}:
let
  userCfgs = lib.mapAttrs (_: cfg: cfg.system) config.jstos;
in
{
  options.jstos = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { ... }:
        {
          options.system = {
            compressMemory = {
              enable = lib.mkEnableOption "compress memory";

              memoryPercent = lib.mkOption {
                type = lib.types.ints.positive;
                default = 66;
                description = ''
                  Maximum amount of memory to use for compression.
                '';
              };
            };
          };
        }
      )
    );
  };

  config = lib.mkMerge [
    (
      let
        # When the kernel supports backing-store-less zswap,
        # we won't need zram at all.
        useZram = config.swapDevices == [ ];

        memoryPercent = lib.foldl' lib.trivial.max 0 (
          builtins.map (cfg: cfg.memoryPercent) (lib.attrValues userCfgs_)
        );

        userCfgs_ = lib.filterAttrs (_: cfg: cfg.enable) (
          lib.mapAttrs (_: cfg: cfg.compressMemory) userCfgs
        );
      in
      lib.mkIf (lib.any (cfg: cfg.enable) (lib.attrValues userCfgs_)) (
        lib.mkMerge [
          (lib.mkIf useZram {
            zramSwap = {
              enable = true;
              # Zram takes size of the swap as a percent of memory,
              # not the percent of memory that can be used for swap.
              # When using zstd,
              # in practice,
              # zram compresses at about a 3:1 ratio,
              # so we multiply the percent of memory to compress by 3.
              memoryPercent = memoryPercent * 3;
            };
          })
          (lib.mkIf (!useZram) {
            # See <https://github.com/NixOS/nixpkgs/pull/470366>.
            # We can use the `zswap` option directly
            # when that pull request is merged.

            # 1. Core configuration: kernel parameters for early boot
            boot.kernelParams = [
              "zswap.enabled=1"
              "zswap.compressor=zstd"
              "zswap.zpool=zsmalloc"
              "zswap.max_pool_percent=${toString memoryPercent}"
              "zswap.accept_threshold_percent=90"
              "zswap.shrinker_enabled=1"
            ];

            # 2. Dependency management: ensure required modules are included in initrd or kernel
            # This ensures Zswap is ready early in the boot process (before swap is mounted)
            boot.initrd.kernelModules = [
              "zstd"
              "zsmalloc"
            ];

            # 3. Runtime configuration using boot.kernel.sysfs
            # This ensures zswap parameters are properly set and maintained during system rebuilds
            boot.kernel.sysfs.module.zswap.parameters = {
              enabled = true;
              compressor = "zstd";
              zpool = "zsmalloc";
              max_pool_percent = memoryPercent;
              accept_threshold_percent = 90;
              shrinker_enabled = true;
            };
          })
        ]
      )
    )
  ];
}
