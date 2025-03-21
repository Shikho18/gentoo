# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/OpenNI/OpenNI"
fi

inherit eapi9-pipestatus flag-o-matic java-pkg-opt-2 toolchain-funcs

if [[ ${PV} != 9999 ]]; then
	KEYWORDS="~amd64 ~arm"
	SRC_URI="https://github.com/OpenNI/OpenNI/archive/Stable-${PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/${PN}-Stable-${PV}"
fi

DESCRIPTION="OpenNI SDK"
HOMEPAGE="https://github.com/OpenNI/OpenNI"
LICENSE="Apache-2.0"
SLOT="0"
IUSE="doc java opengl"

COMMON_DEPEND="
	media-libs/libjpeg-turbo:=
	virtual/libusb:1
	virtual/libudev
	dev-libs/tinyxml
	opengl? ( media-libs/freeglut !dev-libs/OpenNI2[opengl] )
"

DEPEND="
	${COMMON_DEPEND}
	java? ( >=virtual/jdk-1.8:* !dev-libs/OpenNI2[java] )
"

RDEPEND="
	${COMMON_DEPEND}
	java? ( >=virtual/jre-1.8:* !dev-libs/OpenNI2[java] )
"

BDEPEND="doc? ( app-text/doxygen )"

PATCHES=(
	"${FILESDIR}/tinyxml.patch"
	"${FILESDIR}/jpeg.patch"
	"${FILESDIR}/soname.patch"
	"${FILESDIR}/${PN}-1.5.7.10-gcc6.patch"
)

src_prepare() {
	default

	rm -rf External/{LibJPEG,TinyXml}
	for i in Platform/Linux/Build/Common/Platform.* Externals/PSCommon/Linux/Build/Platform.* ; do
		echo "" > ${i} || die
	done

	local status
	find . -type f -print0 |
		xargs -0 sed -i "s:\".*/SamplesConfig.xml:\"${EPREFIX}/usr/share/${PN}/SamplesConfig.xml:"
	status=$(pipestatus -v) || die "fails to sed SamplesConfig, (PIPESTATUS: ${status})"
}

src_compile() {
	# bug #855671
	append-flags -fno-strict-aliasing

	emake -C "${S}/Platform/Linux/Build" \
		CC="$(tc-getCC)" \
		CXX="$(tc-getCXX)" \
		GLUT_SUPPORTED="$(usex opengl 1 0)" \
		$(usex java "" ALL_JAVA_PROJS="") \
		$(usex java "" JAVA_SAMPLES="") \
		ALL_MONO_PROJS="" \
		MONO_SAMPLES="" \
		MONO_FORMS_SAMPLES=""

	if use doc ; then
		cd Source/DoxyGen || die
		doxygen || die
	fi
}

src_install() {
	dolib.so Platform/Linux/Bin/*Release/*.so

	insinto /usr/include/openni
	doins -r Include/*

	dobin Platform/Linux/Bin/*Release/{ni*,Ni*,Sample-*}

	if use java ; then
		java-pkg_dojar Platform/Linux/Bin/*Release/*.jar
		echo "java -jar ${JAVA_PKG_JARDEST}/org.openni.Samples.SimpleViewer.jar" \
			 > org.openni.Samples.SimpleViewer || die
		dobin org.openni.Samples.SimpleViewer
	fi

	insinto /usr/share/${PN}
	doins Data/*

	dodoc Documentation/OpenNI_UserGuide.pdf CHANGES NOTICE README

	if use doc ; then
		docinto html
		dodoc -r Source/DoxyGen/html/*
		dodoc Source/DoxyGen/Text/*.txt
	fi

	keepdir /var/lib/ni
}

pkg_postinst() {
	if [[ "${ROOT:-/}" = "/" ]]; then
		for i in "${EROOR}/usr/$(get_libdir)"/libnim*.so ; do
			einfo "Registering module ${i}"
			niReg -r "${i}"
		done
	fi
}
