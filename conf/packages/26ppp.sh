
PACKAGES+=" ppp"
hset ppp url "ftp://ftp.samba.org/pub/ppp/ppp-2.4.1.tar.gz"

install-ppp() {
	install-generic
	chmod 0755 $(get_installed_binaries)
}

deploy-ppp() {
	deploy cp $(get_installed_binaries) "$ROOTFS"/bin/
}
