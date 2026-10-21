# gopass-menu: pick a gopass entry in fuzzel, then what to do with it: type
# (wtype) or copy (gopass -c, cleared after core.cliptimeout) its password, a
# `key: value` field of its body or its OTP; with a user field, also type
# user, Tab, password. Secrets go to wtype on stdin, never as arguments.

menu() { fuzzel --dmenu --only-match --prompt "$1"; }
type_text() { printf %s "$1" | wtype -; }

entry=$(gopass ls --flat | menu "gopass> ") || exit 0
[ -n "$entry" ] || exit 0

# The body only (line 1 is the password); its keys and whether it has an OTP.
body=$(gopass show --noparsing --unsafe "$entry" | tail -n +2)
mapfile -t keys < <(sed -n 's/^\([^ :][^:]*\): .*/\1/p' <<<"$body" | grep -vx password | sort -u)
user_key=
for k in user username login email; do
  if printf '%s\n' "${keys[@]}" | grep -qx "$k"; then
    user_key=$k
    break
  fi
done

actions=()
[ -z "$user_key" ] || actions+=("Type $user_key ⇥ password")
actions+=("Type password" "Copy password")
if grep -qE '^(otpauth://|totp: )' <<<"$body"; then
  actions+=("Type OTP" "Copy OTP")
fi
for k in "${keys[@]}"; do
  actions+=("Type $k" "Copy $k")
done

action=$(printf '%s\n' "${actions[@]}" | menu "$entry> ") || exit 0

# Fetch before typing so a pinentry prompt doesn't steal the keystrokes, then
# give the focus a moment to return to the window from fuzzel.
case $action in
  "Type $user_key ⇥ password")
    user=$(gopass show "$entry" "$user_key")
    pass=$(gopass show --password "$entry")
    sleep 0.2
    type_text "$user"
    wtype -k Tab
    type_text "$pass"
    ;;
  "Type password")
    pass=$(gopass show --password "$entry")
    sleep 0.2
    type_text "$pass"
    ;;
  "Copy password") gopass show --clip "$entry" >/dev/null ;;
  "Type OTP")
    otp=$(gopass otp --password "$entry")
    sleep 0.2
    type_text "$otp"
    ;;
  "Copy OTP") gopass otp --clip "$entry" >/dev/null ;;
  "Type "*)
    value=$(gopass show "$entry" "${action#Type }")
    sleep 0.2
    type_text "$value"
    ;;
  "Copy "*) gopass show --clip "$entry" "${action#Copy }" >/dev/null ;;
esac
