#!/bin/bash

set -e

if [[ "x$1" == "x" ]] || [[ "x$2" == "x" ]]; then
	echo "Usage $0: [dest_dir] [nix_dir]"
	exit 1
fi

export DEST_DIR=$1
export NIX_DIR=$2
export MY_PERL_LIB_PREFIX=$DEST_DIR/perl-bootstrap
export MY_PERL_LIB_DIR=${MY_PERL_LIB_PREFIX}/lib/perl5/


export PERL5LIB=${DEST_DIR}/lib/perl5/5.24.0
export PATH=${DEST_DIR}/bin:$PATH

export CFLAGS="${CFLAGS} -I${DEST_DIR}/include"
export LDFLAGS="${LDFLAGS} -L${DEST_DIR}/lib"

function bootstrap_perl_int() {

echo "** bootstrap perl interpreter **"
pushd $(mktemp -d)
wget http://www.cpan.org/src/5.0/perl-5.24.0.tar.gz
tar xvzf perl-5.24.0.tar.gz
pushd perl-5.24.0
./Configure -des -Dprefix=$DEST_DIR && make -j
make install 
popd
popd

}

function bootstrap_perl() {

echo "** bootstrap Perl \( until it get removed ... \) "
echo "*** bootstrap perl local::lib "

pushd $(mktemp -d)
wget http://search.cpan.org/CPAN/authors/id/H/HA/HAARG/local-lib-2.000018.tar.gz
tar xvzf local-lib-2.000018.tar.gz
pushd local-lib-2.000018


perl Makefile.PL --bootstrap=${MY_PERL_LIB_PREFIX}
make test && make install

rm -f ${MY_PERL_LIB_PREFIX}/setup
PERL_IMPORT="perl -I $MY_PERL_LIB_DIR -Mlocal::lib"
PERL_SOURCECMD=$(eval "$PERL_IMPORT")
echo "$PERL_SOURCECMD" >> ${MY_PERL_LIB_PREFIX}/setup

popd
popd

}


function perl_setup () {

echo "*** setup perl env *** "

source ${MY_PERL_LIB_PREFIX}/setup

}

function perl_curl_import () {
echo "*** install required perl modules "

cpan WWW::Curl

cpan DBD:SQLite

}

function bootstrap_lzma() {

echo "** bootstrap liblzma **"
pushd $(mktemp -d)
wget http://tukaani.org/xz/xz-5.2.2.tar.gz
tar xvzf xz-5.2.2.tar.gz
pushd xz-5.2.2
./configure --prefix=$DEST_DIR && make -j
make install 
popd
popd

}

function bootstrap_bzip2() {
echo "** bootstrap bzip2 **"
pushd $(mktemp -d)
wget http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz
tar xvzf bzip2*
pushd bzip2-1.0.6
make PREFIX=${DEST_DIR} -j 
make PREFIX=${DEST_DIR} install
popd
popd

}

function bootstrap_curl() {
echo "** bootstrap curl **"
pushd $(mktemp -d)
curl -L https://curl.haxx.se/download/curl-7.50.3.tar.gz -o curl-7.50.3.tar.gz
tar xvzf curl-7.50.3.tar.gz
pushd curl-7.50.3
./configure --prefix=${DEST_DIR}
make PREFIX=${DEST_DIR} -j
make PREFIX=${DEST_DIR} install
popd
popd

}


bootstrap_sqlite() {
echo "** bootstrap sqlite **"
pushd $(mktemp -d)
wget https://www.sqlite.org/snapshot/sqlite-snapshot-201609191100.tar.gz
tar xvzf sqlite-snapshot-201609191100.tar.gz
pushd sqlite-snapshot-201609191100
./configure --prefix=${DEST_DIR}
make PREFIX=${DEST_DIR} -j
make PREFIX=${DEST_DIR} install
popd
popd



}


function deploy_nix() {

echo "** start nix compilation **"
echo "*** configure nix"

export CC="${NIX_CC}"
export CXX="${NIX_CXX}"
export NIX_INCLUDES="${NIX_INCLUDES} -I ./src/libutil -I./ "

export LD_LIBRARY_PATH="${DEST_DIR}/lib:${LD_LIBRARY_PATH}"

export PKG_CONFIG_PATH="${DEST_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"
export LIBLZMA_LIBS="-L${DEST_DIR}/lib -llzma"
export CXXFLAGS="-pthread ${NIX_INCLUDES} -I${DEST_DIR}/include -L${DEST_DIR}/lib" 
export CPPFLAGS="${CXXFLAGS}"


echo "*** configure **"
./configure  --prefix=${DEST_DIR} --with-store-dir=${NIX_DIR}/store --localstatedir=${NIX_DIR}/var --disable-doc-gen 


echo "*** build nix"
echo "compile flags: ${CXXFLAGS} "
make  -e V=1 

echo "*** install nix under prefix ${DEST_DIR}"
make install


}


#bootstrap_curl
bootstrap_sqlite 
bootstrap_perl_int
bootstrap_perl
perl_setup 
perl_curl_import
#bootstrap_bzip2
bootstrap_lzma
deploy_nix
