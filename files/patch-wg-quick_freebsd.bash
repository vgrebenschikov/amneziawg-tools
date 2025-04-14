--- wg-quick/freebsd.bash.orig	2024-10-01 13:02:42 UTC
+++ wg-quick/freebsd.bash
@@ -25,11 +25,16 @@ CONFIG_FILE=""
 POST_DOWN=( )
 SAVE_CONFIG=0
 CONFIG_FILE=""
+DESCRIPTION=""
 PROGRAM="${0##*/}"
 ARGS=( "$@" )
 
 IS_ASESCURITY_ON=0
 
+
+declare -A ROUTES
+
+
 cmd() {
 	echo "[#] $*" >&3
 	"$@"
@@ -40,7 +45,7 @@ die() {
 	exit 1
 }
 
-CONFIG_SEARCH_PATHS=( /etc/amnezia/amneziawg /usr/local/etc/amnezia/amneziawg )
+CONFIG_SEARCH_PATHS=( /usr/local/etc/wireguard /usr/local/etc/amnezia/amneziawg )
 
 unset ORIGINAL_TMPDIR
 make_temp() {
@@ -64,7 +69,7 @@ parse_options() {
 }
 
 parse_options() {
-	local interface_section=0 line key value stripped path v
+	local interface_section=0 line key value stripped path v last_public_key 
 	CONFIG_FILE="$1"
 	if [[ $CONFIG_FILE =~ ^[a-zA-Z0-9_=+.-]{1,15}$ ]]; then
 		for path in "${CONFIG_SEARCH_PATHS[@]}"; do
@@ -82,7 +87,7 @@ parse_options() {
 		stripped="${line%%\#*}"
 		key="${stripped%%=*}"; key="${key##*([[:space:]])}"; key="${key%%*([[:space:]])}"
 		value="${stripped#*=}"; value="${value##*([[:space:]])}"; value="${value%%*([[:space:]])}"
-		[[ $key == "["* ]] && interface_section=0
+		[[ $key == "["* ]] && interface_section=0 && last_public_key=""
 		[[ $key == "[Interface]" ]] && interface_section=1
 		if [[ $interface_section -eq 1 ]]; then
 			case "$key" in
@@ -96,12 +101,17 @@ parse_options() {
 			PreDown) PRE_DOWN+=( "$value" ); continue ;;
 			PostUp) POST_UP+=( "$value" ); continue ;;
 			PostDown) POST_DOWN+=( "$value" ); continue ;;
+			Description) DESCRIPTION="$value"; continue ;;
 			SaveConfig) read_bool SAVE_CONFIG "$value"; continue ;;
 			esac
 			case "$key" in
-			Jc);&
-			Jmin);&
-			Jmax);&
+			
+			# supported by wireguard-amnezia-kmod
+			Jc);;
+			Jmin);;
+			Jmax);;
+			
+			# not yet supported by wireguard-amnezia-kmod
 			S1);&
 			S2);&
 			H1);&
@@ -109,6 +119,12 @@ parse_options() {
 			H3);&
 			H4) IS_ASESCURITY_ON=1;;
 			esac
+		else
+			case "$key" in
+			PublicKey) last_public_key="$value" ;;
+			Routes) ROUTES["$last_public_key"]="$value"; continue ;;
+			DynamicRoutes) continue ;;
+			esac
 		fi
 		WG_CONFIG+="$line"$'\n'
 	done < "$CONFIG_FILE"
@@ -133,8 +149,11 @@ add_if() {
 	if [[ $IS_ASESCURITY_ON == 1 ]]; then
 		cmd="amneziawg-go "$INTERFACE"";
 	fi
-	if ret="$(cmd $cmd 2>&1 >/dev/null)"; then
-		return 0
+	if [ -n "$DESCRIPTION" ]; then
+		ret="$(cmd $cmd description "$DESCRIPTION" 2>&1 >/dev/null)" && return 0
+	else
+
+		ret="$(cmd $cmd 2>&1 >/dev/null)" && return 0
 	fi
 	rc=$?
 	if [[ $ret == *"ifconfig: ioctl SIOCSIFNAME (set name): File exists"* ]]; then
@@ -301,14 +320,13 @@ monitor_daemon() {
 	(make_temp
 	trap 'del_routes; clean_temp; exit 0' INT TERM EXIT
 	exec >/dev/null 2>&1
-	exec 19< <(exec route -n monitor)
+	exec 19< <(exec stdbuf -oL route -n monitor)
 	local event pid=$!
 	# TODO: this should also check to see if the endpoint actually changes
 	# in response to incoming packets, and then call set_endpoint_direct_route
 	# then too. That function should be able to gracefully cleanup if the
 	# endpoints change.
 	while read -u 19 -r event; do
-		[[ $event == RTM_* ]] || continue
 		ifconfig "$INTERFACE" >/dev/null 2>&1 || break
 		[[ $AUTO_ROUTE4 -eq 1 || $AUTO_ROUTE6 -eq 1 ]] && set_endpoint_direct_route
 		# TODO: set the mtu as well, but only if up
@@ -433,6 +451,20 @@ cmd_usage() {
 	_EOF
 }
 
+get_routes() {
+	while read -r pub_key i; do
+		if [[ -v "ROUTES[$pub_key]" ]]; then
+			for route in ${ROUTES[$pub_key]//,/ }; do
+				echo "$route"
+			done
+		else
+			for j in $i; do 
+				[[ $j =~ ^[0-9a-z:.]+/[0-9]+$ ]] && echo "$j"
+			done
+		fi
+	done < <(wg show "$INTERFACE" allowed-ips) | sort -nr -k 2 -t /
+}
+
 cmd_up() {
 	local i
 	[[ -z $(ifconfig "$INTERFACE" 2>/dev/null) ]] || die "\`$INTERFACE' already exists"
@@ -446,7 +478,7 @@ cmd_up() {
 	set_mtu
 	up_if
 	set_dns
-	for i in $(while read -r _ i; do for i in $i; do [[ $i =~ ^[0-9a-z:.]+/[0-9]+$ ]] && echo "$i"; done; done < <(wg show "$INTERFACE" allowed-ips) | sort -nr -k 2 -t /); do
+	for i in $(get_routes); do
 		add_route "$i"
 	done
 	[[ $AUTO_ROUTE4 -eq 1 || $AUTO_ROUTE6 -eq 1 ]] && set_endpoint_direct_route
