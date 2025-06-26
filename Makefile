PORTNAME=	amneziawg-tools
VERSIONPREFIX=	v
PORTVERSION=	1.0.20241018
PORTREVISION=	5
CATEGORIES=	net net-vpn
MASTER_SITES=	https://github.com/amnezia-vpn/amneziawg-tools

MAINTAINER=	vova@zote.me
COMMENT=	Fast, modern and secure VPN Tunnel with AmneziaVPN anti-detection tweaks
WWW=		https://github.com/amnezia-vpn/amneziawg-tools

LICENSE=	GPLv2


USES=		gmake
USE_GITHUB=	yes
GH_ACCOUNT=	amnezia-vpn
GH_TAGNAME=	${VERSIONPREFIX}${PORTVERSION}


WRKSRC_SUBDIR=	src

MAKE_ARGS+=	DEBUG=no WITH_BASHCOMPLETION=yes WITH_SYSTEMDUNITS=no
MAKE_ENV+=	MANDIR="${PREFIX}/share/man" \
		SYSCONFDIR="${PREFIX}/etc"

RUN_DEPENDS=	bash:shells/bash

WGQUICK_DESC=		awg-quick(8) userland utility
WGQUICK_RUN_DEPENDS=	bash:shells/bash
USE_RC_SUBR=		wireguard_awgquick

.include <bsd.port.options.mk>

post-patch:
	@${REINPLACE_CMD} -e 's|/usr/local|${LOCALBASE}|g' \
		${WRKSRC}/completion/wg-quick.bash-completion \
		${WRKSRC}/wg-quick/freebsd.bash
	@${REINPLACE_CMD} -e 's|wg s|awg s|g' \
		${WRKSRC}/completion/wg-quick.bash-completion \
		${WRKSRC}/wg-quick/freebsd.bash

install-rc-script:
	@${ECHO_MSG} "===> Staging rc.d startup script(s)"
	@for i in ${USE_RC_SUBR}; do \
		_prefix=${PREFIX}; \
		[ "${PREFIX}" = "/usr" ] && _prefix="" ; \
		${INSTALL_SCRIPT} ${WRKDIR}/$${i} ${STAGEDIR}$${_prefix}/etc/rc.d/wireguard-amnezia; \
		${ECHO_CMD} "@(root,wheel,0755) $${_prefix}/etc/rc.d/wireguard-amnezia" >> ${TMPPLIST}; \
	done

.include <bsd.port.mk>
