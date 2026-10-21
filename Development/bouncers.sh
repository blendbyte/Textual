#!/bin/sh
#
# The test bouncers in the VM, for bouncer accounts: soju and ZNC, each with
# user "dan" (password "textual") and two networks on the VM's Ergo. Run by
# vm-dev bouncer (TextualTest/vm-dev, made by Development/dev vm-bundle):
#
#   bouncers.sh setup <dir>     configuration, certificates (first start only)
#   bouncers.sh accounts <dir>  users and networks (first start only), then status
#   bouncers.sh status <dir>    which bouncers run, where
#   bouncers.sh log <dir>       their logs
#
# soju: 127.0.0.1 6670, TLS 6671 (self-signed). ZNC: 6672, TLS 6673 (self-signed).
# Networks: soju "Ergo" and "Ergo Two" (nicknames sojudan, sojudan2), ZNC "ergo"
# and "ergotwo" (zncdan, zncdan2), all on Ergo at 127.0.0.1 6667.

set -eu

command="${1:-}"
dir="${2:-}"

[ -n "${command}" ] && [ -d "${dir}" ] || { echo "bouncers.sh setup|accounts|status|log <dir>" >&2; exit 1; }

soju="${dir}/soju"
znc="${dir}/znc"
zncdata="${dir}/znc-data"
logs="$(dirname "${dir}")"

setup() {
	# soju
	if [ ! -f "${soju}/config" ]; then
		/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=soju.textual.test" \
			-keyout "${soju}/key.pem" -out "${soju}/cert.pem" 2> /dev/null

		cat > "${soju}/config" <<-EOF
		hostname soju.textual.test
		listen irc+insecure://127.0.0.1:6670
		listen ircs://127.0.0.1:6671
		listen unix+admin://${soju}/admin.sock
		tls ${soju}/cert.pem ${soju}/key.pem
		db sqlite3 ${soju}/soju.db
		message-store fs ${soju}/logs
		client-cert-auth true
		EOF
	fi

	# ZNC (its configuration only on the first start: ZNC rewrites it)
	if [ ! -f "${zncdata}/configs/znc.conf" ]; then
		mkdir -p "${zncdata}/configs"

		"${znc}/bin/znc" --datadir "${zncdata}" --makepem > /dev/null 2>&1

		salt=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)
		hash=$(printf '%s' "textual${salt}" | shasum -a 256 | cut -d ' ' -f 1)

		cat > "${zncdata}/configs/znc.conf" <<-EOF
		Version = 1.10.3
		<Listener plain>
			Port = 6672
			IPv4 = true
			IPv6 = false
			SSL = false
			AllowIRC = true
			AllowWeb = false
		</Listener>
		<Listener tls>
			Port = 6673
			IPv4 = true
			IPv6 = false
			SSL = true
			AllowIRC = true
			AllowWeb = false
		</Listener>
		<User dan>
			Pass = sha256#${hash}#${salt}#
			Admin = true
			Nick = zncdan
			AltNick = zncdan_
			Ident = dan
			RealName = Dan through ZNC
			LoadModule = chansaver
			LoadModule = controlpanel
			<Network ergo>
				Server = 127.0.0.1 6667
				Nick = zncdan
			</Network>
			<Network ergotwo>
				Server = 127.0.0.1 6667
				Nick = zncdan2
			</Network>
		</User>
		EOF
	fi
}

accounts() {
	if [ ! -f "${soju}/.accounts" ]; then
		ctl() { "${soju}/sojuctl" -config "${soju}/config" "$@"; }

		ctl user create -username dan -password textual -nick sojudan
		ctl user run dan network create -addr irc+insecure://127.0.0.1:6667 -name Ergo -nick sojudan
		ctl user run dan network create -addr irc+insecure://127.0.0.1:6667 -name "Ergo Two" -nick sojudan2

		touch "${soju}/.accounts"
	fi

	status
}

status() {
	if pgrep -f "^${soju}/soju " > /dev/null; then
		echo "soju is running: 127.0.0.1 6670 (plain), 6671 (TLS); user dan, password textual"
	else
		echo "soju is not running; see ${logs}/soju.log"
	fi

	if pgrep -f "^${znc}/bin/znc " > /dev/null; then
		echo "ZNC is running: 127.0.0.1 6672 (plain), 6673 (TLS); user dan, password textual"
	else
		echo "ZNC is not running; see ${logs}/znc.log"
	fi
}

case "${command}" in
	setup) setup ;;
	accounts) accounts ;;
	status) status ;;
	log)
		for name in soju znc; do
			echo "== ${name}"
			tail -n 40 "${logs}/${name}.log" 2> /dev/null || true
		done
		;;
	*) echo "bouncers.sh setup|accounts|status|log <dir>" >&2; exit 1 ;;
esac
