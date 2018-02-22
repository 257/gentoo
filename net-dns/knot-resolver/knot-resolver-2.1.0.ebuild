# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit flag-o-matic user git-r3

DESCRIPTION="A caching full DNS resolver implementation written in C and LuaJIT"
HOMEPAGE="https://www.knot-resolver.cz"
#SRC_URI="https://secure.nic.cz/files/${PN}/${P}.tar.xz"
EGIT_REPO_URI="https://github.com/CZ-NIC/knot-resolver.git"
EGIT_COMMIT=v"${PV}"
#EGIT_BRANCH="
#RESTRICT="mirror"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="dnstap go pie systemd test"

RDEPEND=">=net-dns/knot-2.3.1
	>=dev-libs/libuv-1.7.0
	dev-lang/luajit:2
	dev-lua/luasocket
	dev-lua/luasec
	dnstap? (
		>=dev-libs/protobuf-3.0
		dev-libs/protobuf-c
		dev-libs/fstrm
	)
	go? ( >=dev-lang/go-1.5.0 )
	systemd? ( sys-apps/systemd )"
DEPEND="${RDEPEND}
	virtual/pkgconfig
	test? (
		dev-util/cmocka
		dnstap? ( >=dev-lang/go-1.5.0 )
	)"

pkg_setup() {
	enewgroup kresd
	enewuser kresd -1 -1 /var/lib/knot-resolver kresd
}

src_prepare() {
	# Gentoo has FORTIFY_SOURCE enabled by default
	sed -i 's/ -D_FORTIFY_SOURCE=2//g' \
		./config.mk || die

	default
}

src_compile() {
	append-cflags -DNDEBUG
	append-cflags $(test-flags-CC -rdynamic)
	emake \
		LDFLAGS="${LDFLAGS}" \
		PREFIX=/usr \
		ETCDIR=/etc/knot-resolver \
		LIBDIR=/usr/"$(get_libdir)" \
		ENABLE_DNSTAP=$(usex dnstap) \
		HARDENING=$(usex pie) \
		HAS_cmocka=$(usex test) \
		HAS_go=$(usex go) \
		HAS_libsystemd=$(usex systemd)
}

src_test() {
	emake check
	use dnstap && emake ckeck-dnstap
}

src_install() {
	emake \
		LDFLAGS="${LDFLAGS}" \
		PREFIX=/usr \
		ETCDIR=/etc/knot-resolver \
		LIBDIR=/usr/"$(get_libdir)" \
		DESTDIR="${D}" install

	newinitd "${FILESDIR}"/${PN}.initd ${PN}
	newconfd "${FILESDIR}"/${PN}.confd ${PN}

	insinto /var/lib/knot-resolver
	doins "${FILESDIR}"/root.keys
	fowners kresd:kresd /var/lib/knot-resolver/root.keys

	insinto /etc/knot-resolver
	newins "${FILESDIR}"/${PN}.config config

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/${PN}.logrotate ${PN}
}

pkg_postinst() {
	if [ -z "${REPLACING_VERSIONS}" ]; then
		einfo
		elog "If you prefer not to use the bundled root.keys, just delete"
		elog "'${EROOT%/}/var/lib/knot-resolver/root.keys', then start ${PN}."
		elog "The bootstrapping of the keys is automated, and kresd fetches"
		elog "root trust anchors set over a secure channel from IANA."
		elog "From there, it can perform automatic updates for you."
		einfo
	fi
}
