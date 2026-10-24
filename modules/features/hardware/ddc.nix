# DDC/CI: control external monitors (brightness, input, volume) over the
# DP AUX / HDMI DDC channel with ddcutil. NixOS loads i2c-dev and gives the
# i2c group access to /dev/i2c-*; home-manager installs ddcutil. A host
# imports both nixos.ddc and homeManager.ddc.
#
# ddc-volume (user service): while the default PipeWire sink is a monitor's
# HDMI/DP audio, its volume (0 when muted) is mirrored to the monitor's
# speaker volume (VCP 0x62). The sink's node.nick is the monitor name from
# its ELD, the same as the EDID model ddcutil reports, which is how the sink
# is matched to a display: plugging such a monitor in is enough. One way
# only: the monitor's own buttons don't change the sink.
{ config, ... }:
{
  nixos.ddc = {
    hardware.i2c.enable = true;
    users.users.${config.my.user}.extraGroups = [ "i2c" ];
  };

  homeManager.ddc =
    { lib, pkgs, ... }:
    let
      ddc-volume = pkgs.writeShellApplication {
        name = "ddc-volume";
        runtimeInputs = [
          pkgs.ddcutil
          pkgs.pulseaudio # pactl, talking to pipewire-pulse
          pkgs.jq
          pkgs.gawk
        ];
        text = ''
          # Sink name -> "bus max" of its display, or "-" (no DDC display).
          declare -A displays=()
          last=""

          # The I2C bus of the display whose EDID model is $1, and the
          # maximum of its VCP 0x62 (not always 100).
          resolve() {
            local bus max
            bus=$(ddcutil detect --terse 2>/dev/null | awk -v model="$1" '
              /^Display/ { ok = 1 } /^Invalid/ { ok = 0 }
              ok && /I2C bus:/ { sub(".*/dev/i2c-", ""); bus = $0 }
              ok && /Monitor:/ { split($0, f, ":"); if (f[3] == model) { print bus; exit } }')
            [[ -n $bus ]] || return 1
            max=$(ddcutil --bus "$bus" --terse getvcp 62 2>/dev/null | awk '{ print $5 }')
            [[ -n $max ]] || return 1
            echo "$bus $max"
          }

          sync() {
            local default sink nick vol bus max
            default=$(pactl get-default-sink) || return 0
            sink=$(pactl -f json list sinks | jq -c --arg n "$default" '
              .[] | select(.name == $n)
              | { nick: (.properties."node.nick" // ""),
                  vol: (if .mute then 0 else
                    [.volume[].value_percent | rtrimstr("%") | tonumber] | max end) }')
            [[ -n $sink ]] || return 0
            nick=$(jq -r .nick <<<"$sink")
            vol=$(jq -r .vol <<<"$sink")
            [[ -n $nick ]] || return 0

            if [[ -z ''${displays[$default]:-} ]]; then
              displays[$default]=$(resolve "$nick" || echo -)
            fi
            [[ ''${displays[$default]} != - ]] || return 0
            read -r bus max <<<"''${displays[$default]}"

            vol=$(( (vol > 100 ? 100 : vol) * max / 100 ))
            [[ "$bus $vol" != "$last" ]] || return 0
            if ddcutil --bus "$bus" --noverify --skip-ddc-checks setvcp 62 "$vol" 2>/dev/null; then
              last="$bus $vol"
            else
              unset 'displays[$default]' # gone or not ready yet: look again next time
            fi
          }

          # A sink came or went (a monitor plugged in): match displays again
          # and resend the volume, which a monitor may have reset.
          forget() {
            displays=()
            last=""
          }

          sync
          # Sink and server (default sink) events; a burst (a held volume
          # key) is coalesced into one setvcp, which takes ~0.3s.
          pactl subscribe | while read -r line; do
            case $line in
              *"'new' on sink"* | *"'remove' on sink"*) forget ;;
              *" on sink #"* | *" on server"*) ;;
              *) continue ;;
            esac
            while read -r -t 0.15 line; do
              case $line in *"'new' on sink"* | *"'remove' on sink"*) forget ;; esac
            done
            sync
          done
        '';
      };
    in
    {
      home.packages = [ pkgs.ddcutil ];

      systemd.user.services.ddc-volume = {
        Unit = {
          Description = "Mirror the default sink's volume to the monitor (DDC/CI)";
          After = [ "pipewire-pulse.service" ];
        };
        Service = {
          ExecStart = lib.getExe ddc-volume;
          Restart = "always";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
