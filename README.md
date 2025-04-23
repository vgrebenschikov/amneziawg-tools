# FreeBSD port of amneziawg-tools

## Installation

Download and build port as:

```shell
# git clone https://github.com/vgrebenschikov/amneziawg-tools
# cd amneziawg-tools
# make install
```

It will install:

```shell
$ pkg list amneziawg-tools
/usr/local/bin/awg
/usr/local/bin/awg-quick
/usr/local/etc/rc.d/wireguard-amnezia
/usr/local/share/bash-completion/completions/awg
/usr/local/share/bash-completion/completions/awg-quick
/usr/local/share/licenses/amneziawg-tools-1.0.20241018_2/GPLv2
/usr/local/share/licenses/amneziawg-tools-1.0.20241018_2/LICENSE
/usr/local/share/licenses/amneziawg-tools-1.0.20241018_2/catalog.mk
/usr/local/share/man/man8/awg-quick.8.gz
/usr/local/share/man/man8/awg.8.gz
```

## Using Kernel AmneziaWG module

Install [net/wireguard-amnezia-kmod](https://github.com/vgrebenschikov/wireguard-amnezia-kmod-port)

Unload original if_wg as and load updated from /boot/modules/if_wg.ko

```shell
# kldunload if_wg
# kldload /boot/modules/if_wg.ko
```

## Configuration

Generally - same way as you will configure normal net/wireguard-tools:

```shell
# cd /usr/local/etc/wireguard
# cat > wg0.conf
[Interface]
PrivateKey = ...our.private.key.here...
ListenPort = 12345
Address = 192.168.1.1/24
Description = Test Wireguard

Jc = 7
Jmin = 150
Jmax = 1000
S1 = 117
S2 = 321
H1 = 2008066467
H2 = 2351746464
H3 = 3053333659
H4 = 1789444460

[Peer]
PublicKey = ...peer.public.key.here...
AllowedIPs = 192.168.1.2/32
^D
```

Then start:

```shell
# awg-quick up wg0
[#] ifconfig wg create name wg0 description Test Wireguard
[#] awg setconf wg0 /dev/stdin
[#] ifconfig wg0 inet 192.168.1.1/24 alias
[#] ifconfig wg0 mtu 1420
[#] ifconfig wg0 up
[#] route -q -n add -inet 192.168.11.0/24 -interface wg0
[+] Backgrounding route monitor

# awg show
interface: wg0
  public key: CI...
  private key: (hidden)
  listening port: 12345
  jc: 7
  jmin: 150
  jmax: 1000
  s1: 117
  s2: 321
  h1: 2008066467
  h2: 2351746464
  h3: 3053333659
  h4: 1789444460

peer: kue...
  allowed ips: 192.168.1.2/32
```

To setup autostart (wireguard-amnezia rc.d script will load module):

```shell
# sysrc wireguard_amnezia_enable=YES wireguard_amnezia_interfaces="wg0"
```

## Amnezia Wireguard config options

## Jc

Number of junk packets before handshake.
1–128 (recomended 3–10)

## Jmin

Minimum size of junk packets.
Jmin: < Jmax (recomended ~ 50)

## Jmax

Maximum size of junk packets.
Jmax: ≤ 1280 (recomended ~ 1000)

## S1

Size of handshake initiation packet prepend junk. Should be the same on both ends.
0–1280 (recomended 15–150)
S1 != S2

## S2

Size of handshake response packet prepend junk. Should be the same on both ends.
0–1280 (recomended 15–150)
S1 != S2

## H1-H4

Custom identifiers for initiation/response/cookie/data packets. Should be the same on both ends.
unique value in range of 4,294,967,295 (0x5 - 0xFFFFFFFF)
H1 != H2 != H3 != H4

## Additional config options

### Description

```config
[Interface]
...
Description = Some Text
```

Will setup interface description visible in ifconfig and SNMP.

### UserLand

Enforce to use amnezia-go instead of kernel driver, you can use port
[net/amnezia-wireguard-go](https://github.com/vgrebenschikov/amnezia-wireguard-go) to install it.

```config
[Interface]
...
UserLand = true
...
```

### Routes

List of routes for the peer to be installed into FIB - that option provides a way to have AllowedIPs list wider then routes installed. Empty list is allowed.

That is useful if routing protocol will work over the link. But remember that internal wireguard routing will happen according to AllowedIPs anyway.

```config
...

[Peer]
PublicKey = ...peer.public.key.here...
AllowedIPs = 0.0.0.0/0
Routes = 192.168.1.2/32
```
