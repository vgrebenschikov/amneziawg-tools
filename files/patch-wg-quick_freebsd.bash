--- wg-quick/freebsd.bash.orig	2024-02-13 14:18:12.000000000 +0100
+++ wg-quick/freebsd.bash	2025-04-11 20:56:45.597490000 +0200
@@ -30,6 +30,10 @@
 
 IS_ASESCURITY_ON=0
 
+
+declare -A ROUTES
+
+
 cmd() {
 	echo "[#] $*" >&3
 	"$@"
@@ -64,7 +68,7 @@
 }
 
 parse_options() {
-	local interface_section=0 line key value stripped path v
+	local interface_section=0 line key value stripped path v last_public_key 
 	CONFIG_FILE="$1"
 	if [[ $CONFIG_FILE =~ ^[a-zA-Z0-9_=+.-]{1,15}$ ]]; then
 		for path in "${CONFIG_SEARCH_PATHS[@]}"; do
@@ -82,7 +86,7 @@
 		stripped="${line%%\#*}"
 		key="${stripped%%=*}"; key="${key##*([[:space:]])}"; key="${key%%*([[:space:]])}"
 		value="${stripped#*=}"; value="${value##*([[:space:]])}"; value="${value%%*([[:space:]])}"
-		[[ $key == "["* ]] && interface_section=0
+		[[ $key == "["* ]] && interface_section=0 && last_public_key=""
 		[[ $key == "[Interface]" ]] && interface_section=1
 		if [[ $interface_section -eq 1 ]]; then
 			case "$key" in
@@ -109,6 +113,12 @@
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
@@ -209,7 +219,7 @@
 		[[ ${BASH_REMATCH[1]} == *:* ]] && family=inet6
 		output="$(route -n get "-$family" "${BASH_REMATCH[1]}" || true)"
 		[[ $output =~ interface:\ ([^ ]+)$'\n' && $(ifconfig "${BASH_REMATCH[1]}") =~ mtu\ ([0-9]+) && ${BASH_REMATCH[1]} -gt $mtu ]] && mtu="${BASH_REMATCH[1]}"
-	done < <(wg show "$INTERFACE" endpoints)
+	done < <(awg show "$INTERFACE" endpoints)
 	if [[ $mtu -eq 0 ]]; then
 		read -r output < <(route -n get default || true) || true
 		[[ $output =~ interface:\ ([^ ]+)$'\n' && $(ifconfig "${BASH_REMATCH[1]}") =~ mtu\ ([0-9]+) && ${BASH_REMATCH[1]} -gt $mtu ]] && mtu="${BASH_REMATCH[1]}"
@@ -242,7 +252,7 @@
 	while read -r _ endpoint; do
 		[[ $endpoint =~ ^\[?([a-z0-9:.]+)\]?:[0-9]+$ ]] || continue
 		ENDPOINTS+=( "${BASH_REMATCH[1]}" )
-	done < <(wg show "$INTERFACE" endpoints)
+	done < <(awg show "$INTERFACE" endpoints)
 }
 
 set_endpoint_direct_route() {
@@ -301,14 +311,13 @@
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
@@ -354,7 +363,7 @@
 }
 
 set_config() {
-	echo "$WG_CONFIG" | cmd wg setconf "$INTERFACE" /dev/stdin
+	echo "$WG_CONFIG" | cmd awg setconf "$INTERFACE" /dev/stdin
 }
 
 save_config() {
@@ -386,7 +395,7 @@
 	done
 	old_umask="$(umask)"
 	umask 077
-	current_config="$(cmd wg showconf "$INTERFACE")"
+	current_config="$(cmd awg showconf "$INTERFACE")"
 	trap 'rm -f "$CONFIG_FILE.tmp"; clean_temp; exit' INT TERM EXIT
 	echo "${current_config/\[Interface\]$'\n'/$new_config}" > "$CONFIG_FILE.tmp" || die "Could not write configuration file"
 	sync "$CONFIG_FILE.tmp"
@@ -433,6 +442,20 @@
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
+	done < <(awg show "$INTERFACE" allowed-ips) | sort -nr -k 2 -t /
+}
+
 cmd_up() {
 	local i
 	[[ -z $(ifconfig "$INTERFACE" 2>/dev/null) ]] || die "\`$INTERFACE' already exists"
@@ -446,7 +469,7 @@
 	set_mtu
 	up_if
 	set_dns
-	for i in $(while read -r _ i; do for i in $i; do [[ $i =~ ^[0-9a-z:.]+/[0-9]+$ ]] && echo "$i"; done; done < <(wg show "$INTERFACE" allowed-ips) | sort -nr -k 2 -t /); do
+	for i in $(get_routes); do
 		add_route "$i"
 	done
 	[[ $AUTO_ROUTE4 -eq 1 || $AUTO_ROUTE6 -eq 1 ]] && set_endpoint_direct_route
@@ -456,7 +479,7 @@
 }
 
 cmd_down() {
-	[[ " $(wg show interfaces) " == *" $INTERFACE "* ]] || die "\`$INTERFACE' is not a WireGuard interface"
+	[[ " $(awg show interfaces) " == *" $INTERFACE "* ]] || die "\`$INTERFACE' is not a WireGuard interface"
 	execute_hooks "${PRE_DOWN[@]}"
 	[[ $SAVE_CONFIG -eq 0 ]] || save_config
 	del_if
@@ -465,7 +488,7 @@
 }
 
 cmd_save() {
-	[[ " $(wg show interfaces) " == *" $INTERFACE "* ]] || die "\`$INTERFACE' is not a WireGuard interface"
+	[[ " $(awg show interfaces) " == *" $INTERFACE "* ]] || die "\`$INTERFACE' is not a WireGuard interface"
 	save_config
 }
 
