{
  config,
  lib,
  ...
}:
let
  cfg = config.jstos.system.compressMemory;
in
{
  options.jstos.system.compressMemory = {
    enable = lib.mkEnableOption "compress memory";

    memoryPercent = lib.mkOption {
      type = lib.types.ints.positive;
      default = 66;
      description = ''
        Maximum amount of memory to use for compression.
      '';
    };
  };

  config = lib.mkMerge [
    (
      let
        # When the kernel supports backing-store-less zswap,
        # we won't need zram at all.
        useZram = config.swapDevices == [ ];
      in
      lib.mkIf cfg.enable (
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
              memoryPercent = cfg.memoryPercent * 3;
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
              "zswap.max_pool_percent=${toString cfg.memoryPercent}"
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
              max_pool_percent = cfg.memoryPercent;
              accept_threshold_percent = 90;
              shrinker_enabled = true;
            };
          })
        ]
      )
    )
  ];
}
