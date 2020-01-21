#! /usr/bin/env bash
# (c) Konstantin Riege

set -e
shopt -s extglob
trap 'die' INT TERM
#trap 'kill -PIPE 0' EXIT # kills parental processes as well - shlog conflict
#trap 'kill -PIPE -- -$$' EXIT # kill all childs - works only if $$ is process group leader
#trap 'kill -PIPE $(jobs -p)' EXIT # same as above
trap 'kill -PIPE $(pstree -p $$ | grep -Eo "\([0-9]+\)" | grep -Eo "[0-9]+") &> /dev/null' EXIT # parse pstree
# AVOID DOUBLE FORKS -> run(){cmd &}; run & -> i.e. cmd gets new process group and cannot be killed

die() {
	[[ $* ]] && echo ":ERROR: $*" || echo ":ERROR: failed"
	exit 1
}

############### GLOBAL VARS ###############

DIR=$HOME/programs
SOURCE=$DIR/SOURCE.me
THREADS=$(cat /proc/cpuinfo | grep -cF processor)
OPT='all'

############### FUNCTIONS ###############

usage() {
	local tools=$(grep '^TOOL=' $0 | cut -d '=' -f 2)
	cat <<- EOF
		DESCRIPTION
		$(basename $0) brings software locally to your linux computer
		!!! we <3 a space-free file-paths !!!

		VERSION
		0.2.0

		SYNOPSIS
		$(basename $0) -i [tool]

		OPTIONS
		-h | --help           # prints this message
		-d | --dir [path]     # installation path - default: $DIR
		-t | --threads [num]  # threads to use for comilation - default: $THREADS
		-i | --install [tool] # tool to install/update (see below) - default: all, but conda-dev

		TOOLS
		$tools

		INFO
		1) to group multiple windows in gnome application dock
		- define StartupWMClass in .desktop file
		- assign value by executing 'xprop WM_CLASS' + click on window

		2) how to execute tools installed via conda
		- to load conda itself, execute 'source $DIR/conda/latest/bin/activate'
		- to load conda tools execute 'conda env list', and 'conda activate [env]'
		- to load non-conda installed perl-modules execute 'export PERL5LIB=$DIR/perl-modules/lib/perl5'
		
		3) to define a tool as default application
		- adapt ~/.config/mimeapps.list
		- adapt ~/.local/share/applications/mimeapps.list

		REFERENCES
		(c) Konstantin Riege
		konstantin{.}riege{a}leibniz-fli{.}de
	EOF

	exit 0
}

checkopt() {
	local arg=false
	case $1 in
		-h | --h | -help | --help) usage;;
		-t | --t | -threads | --threads) arg=true; THREADS=$2;;
		-i | --i | -install | --install) arg=true; OPT=$2;;
		-d | --d | -dir | --dir) arg=true; DIR=$2; SOURCE=$DIR/SOURCE.me; [[ $(mkdir -p $DIR &> /dev/null; echo $?) -gt 0 ]] && die 'check your installation path';;
		-*) die "illegal option $1";;
		*) die "illegal option $2";;
	esac
	$arg && {
		[[ ! $2 ]] && die "argument missing for option $1"
		[[ "$2" =~ ^- ]] && die "illegal argument $2 for option $1"
		return 0
	} || {
		[[ $2 ]] && [[ ! "$2" =~ ^- ]] && die "illegal argument $2 for option $1"
		return 0
	}
}

setup_cron () {
	crontab -r &> /dev/null
	# <minute> <hour> <day of month> <month> <day of week> <command>
	src=$(cd $(dirname $0) && echo $PWD)
	echo "0 0 1 * * $scriptdir/$(basename $0)" > $src/cron.jobs
	# crontab $src/cron.jobs
}
#setup_cron

run () {
	FOUND=true
	# backup
	mkdir -p $DIR/$TOOL && cd $DIR/$TOOL
	$1 || die $TOOL
	# adapt source
	touch $SOURCE
	if [[ $BIN && ! $(grep "$DIR/$TOOL/$BIN" $SOURCE) ]]; then 
		sed -i "/PATH=/d;" $SOURCE
		echo 'VAR=$VAR:'"$DIR/$TOOL/$BIN" >> $SOURCE
		echo 'PATH=$VAR:$PATH' >> $SOURCE
	fi

	return 0
}

javawrapper() {
	cat <<- EOF > $1 || return 1
		#!/usr/bin/env bash
		set -eu -o pipefail
		export LC_ALL=en_US.UTF-8
		java=java
		if [[ -n \$JAVA_HOME ]]; then
		    if [[ -e \$JAVA_HOME/bin/java ]]; then
		        java=\$JAVA_HOME/bin/java
		    fi
		fi
		jvm_mem_opts=""
		jvm_prop_opts=""
		pass_args=""
		for arg in \$@; do
			case \$arg in
				'-D'*) jvm_prop_opts="\$jvm_prop_opts \$arg";;
				'-XX'*) jvm_prop_opts="\$jvm_prop_opts \$arg";;
				'-Xm'*) jvm_mem_opts="\$jvm_mem_opts \$arg";;
			esac
		done
		[[ ! \$jvm_mem_opts ]] && jvm_mem_opts="-Xms512m -Xmx1g"
		pass_arr=(\$pass_args)
		if [[ \${pass_arr[0]} == org* ]]; then
		    eval \$java \$jvm_mem_opts \$jvm_prop_opts -cp $2 \$pass_args
		else
		    eval \$java \$jvm_mem_opts \$jvm_prop_opts -jar $2 \$pass_args
		fi
		exit
	EOF
	chmod 755 $1 || return 1
	return 0
}

############### MAIN ###############

[[ $# -eq 0 ]] && usage
[[ $# -eq 1 ]] && [[ ! $1 =~ ^- ]] && die "illegal option $1"
for i in $(seq 1 $#); do
	if [[ ${!i} =~ ^- ]]; then
		j=$((i+1))
		checkopt "${!i}" "${!j}" || die
	else 
		((++i))
	fi
done

TOOL=google-chrome         # google chrome webbrowser
install_google-chrome() {
	local url version
	{	url='https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' && \
		wget $url -O $TOOL.deb && ar p $TOOL.deb data.tar.xz | tar xJ && rm $TOOL.deb && \
		version=$(opt/google/chrome/google-chrome --version | perl -lane '$_=~/([\d.]+)/; print $1') && \
		rm -rf $version && mv opt $version && rm -rf usr && rm -rf etc && \
		ln -sfn $version latest && \
		BIN=latest/google/chrome
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-chrome.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Chrome
		Exec=$DIR/$TOOL/$BIN/google-chrome %U
		Type=Application
		Icon=$DIR/$TOOL/$BIN/product_logo_128.png
		StartupWMClass=Google-chrome
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=vivaldi               # sophisticated chrome based webbrowser - highly recommended :)
install_vivaldi() {
	local url version
	{	url=$(curl -s https://vivaldi.com/download/archive/?platform=linux| grep -Eo 'http[^"]+vivaldi-stable[^"]+amd64.deb' | sort -V | tail -1) && \
		version=$(echo $url | perl -lane '$_=~/stable_([^_]+)/; print $1') && \
		echo $version && \
		wget $url -O $TOOL.deb && ar p $TOOL.deb data.tar.xz | tar xJ && rm $TOOL.deb && \
		rm -rf $version  && mv opt $version && rm -rf usr && rm -rf etc && \
		ln -sfn $version latest && \
		BIN=latest/vivaldi
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-vivaldi.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Vivaldi
		Exec=$DIR/$TOOL/$BIN/vivaldi %U
		Type=Application
		Icon=$DIR/$TOOL/$BIN/product_logo_128.png
		StartupWMClass=Vivaldi-stable
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=opera                 # chrome based webbrowser with vpn
install_opera() {
	local url version
	{	version=$(curl -s https://get.geo.opera.com/pub/opera/desktop/ | grep -oE 'href="[^"\/]+' | tail -1 | cut -d '"' -f2) && \
        url="https://get.geo.opera.com/pub/opera/desktop/$version/linux/opera-stable_${version}_amd64.deb"
		echo $version && \
		wget $url -O $TOOL.deb && ar p $TOOL.deb data.tar.xz | tar xJ && rm $TOOL.deb && \
		rm -rf $version && mv usr $version && \
		ln -sfn $version latest && \
		BIN=latest/bin
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-opera.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Opera
		Exec=$DIR/$TOOL/$BIN/opera %U
		Type=Application
		Icon=$DIR/$TOOL/share/icons/hicolor/256x256/apps/opera.png
		StartupWMClass=Opera
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=firefox               # updates via interface possible. firefox webbrowser
install_firefox() {
	local url version
	{	version=$(basename $(curl -s https://ftp.mozilla.org/pub/firefox/releases/ | grep -Eo 'releases/[0-9][^"]+' | grep -Ev 'b[0-9]' | sort -V | tail -1)) && \
		url="https://ftp.mozilla.org/pub/firefox/releases/$version/linux-x86_64/en-US/firefox-$version.tar.bz2" && \
		wget $url -O $TOOL.tar.bz2 && tar -xjf $TOOL.tar.bz2 && rm $TOOL.tar.bz2 && \
		rm -rf $version && mv firefox* $version && \
		ln -sfn $version latest && \
		BIN=latest
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-firefox.desktop || return 1
		[Desktop Entry]
		Name=Firefox
		Exec=$DIR/$TOOL/$BIN/firefox %u
		Icon=$DIR/$TOOL/$BIN/browser/chrome/icons/default/default128.png
		Terminal=false
		Type=Application
		StartupWMClass=Firefox
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=thunderbird           # updates itself. thunderbird email tool
install_thunderbird() {
	local url version
	# https://ftp.mozilla.org/pub/thunderbird/candidates/
	{	version=$(basename $(curl -s https://ftp.mozilla.org/pub/thunderbird/releases/ | grep -Eo 'releases/[0-9][^"]+' | grep -Ev 'b[0-9]' | sort -V | tail -1)) && \
		url="https://ftp.mozilla.org/pub/thunderbird/releases/$version/linux-x86_64/en-US/thunderbird-$version.tar.bz2" && \
		wget $url -O $TOOL.tar.bz2 && tar -xjf $TOOL.tar.bz2 && rm $TOOL.tar.bz2 && \
		rm -rf $version && mv thunderbird* $version && \
		ln -sfn $version latest && \
		BIN=latest
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-thunderbird.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Thunderbird
		Exec=$DIR/$TOOL/$BIN/thunderbird
		Type=Application
		Icon=$DIR/$TOOL/$BIN/chrome/icons/default/default128.png
		StartupWMClass=Thunderbird
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=keeweb               # keepass db compatible password manager with cloud sync support
install_keeweb() {
	local url version
	{	url='https://github.com'$(curl -s https://github.com/keeweb/keeweb/releases | grep -m 1 -Eo '[^"]+linux.x64.zip') && \
		version=$(basename $(dirname $url)) && \
        version=${version:1} && \
        rm -rf $version && mkdir $version && \
		wget $url -O $TOOL.zip && unzip -q $TOOL.zip -d $version && rm $TOOL.zip && \
		ln -sfn $version latest && \
		BIN=latest
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-keeweb.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=KeeWeb
		Exec=$DIR/$TOOL/$BIN/KeeWeb
		Type=Application
		Icon=$DIR/$TOOL/$BIN/128x128.png
		StartupWMClass=KeeWeb
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=java                  # oracle java 11 runtime and development kit
install_java() {
	local url version
	{	url="https://download.oracle.com/otn-pub/java/jdk/13.0.2+8/d4173c853231432d94f001e99d882ca7/jdk-13.0.2_linux-x64_bin.tar.gz" && \
		version=$(echo $url | perl -lane '$_=~/jdk-([^-_]+)/; print $1') && \
		wget --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" $url -O $TOOL.tar.gz && \
		tar -xzf $TOOL.tar.gz && rm $TOOL.tar.gz && \
		rm -rf $version && mv jdk* $version && \
		ln -sfn $version latest && \
		BIN=latest/bin && \
		return 0
	} || return 1
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=master-pdf-editor     # nice pdf viewer and editor
install_master-pdf-editor() {
	local url version
	{	url=$(curl -s https://code-industry.net/free-pdf-editor/ | grep -Eo 'http[^"]+qt5.amd64.tar.gz') && \
		version=$(echo $url | perl -lane '$_=~/(\d[\d.]+)/; print $1') && \
		wget $url -O $TOOL.tar.gz && tar -xzf $TOOL.tar.gz && rm $TOOL.tar.gz && \
		rm -rf $version && mv master-pdf-editor* $version && \
		ln -sfn $version latest && \
		BIN=latest
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-masterpdfeditor.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Masterpdfeditor
		Exec=$DIR/$TOOL/$BIN/masterpdfeditor5
		Type=Application
		Icon=$DIR/$TOOL/$BIN/masterpdfeditor5.png
		StartupWMClass=Masterpdfeditor5
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=sublime               # very powerful text editor and integrated developer environment for all languages
install_sublime() {
	local url version
	{	url=$(curl -s  https://www.sublimetext.com/3 | grep -Eo 'http[^"]+x64.tar.bz2') && \
		version=$(echo $url | perl -lane '$_=~/build_([^_]+)/; print $1') && \
		wget $url -O $TOOL.tar.bz2 && tar -xjf $TOOL.tar.bz2 && rm $TOOL.tar.bz2 && \
		rm -rf $version && mv sublime* $version && \
		ln -sfn sublime_text $version/subl && \
		ln -sfn $version latest && \
		BIN=latest
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-sublime.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Sublime
		Exec=$DIR/$TOOL/$BIN/sublime_text
		Type=Application
		Icon=$DIR/$TOOL/$BIN/Icon/256x256/sublime-text.png
		StartupWMClass=Subl
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=sublime-merge         # very powerful git client
install_sublime-merge() {
	local url version
	{	url=$(curl -s https://www.sublimemerge.com/download | grep -Eo 'http[^"]+x64.tar.xz' | sort -V | tail -1) && \
		version=$(echo $url | perl -lane '$_=~/build_([^_]+)/; print $1') && \
		wget $url -O $TOOL.tar.xz && tar -xf $TOOL.tar.xz && rm $TOOL.tar.xz && \
		rm -rf $version && mv sublime* $version && \
		ln -sfn sublime_text $version/sublmerge && \
		ln -sfn $version latest && \
		BIN=latest
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-sublime-merge.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Sublime Merge
		Exec=$DIR/$TOOL/$BIN/sublime_merge
		Type=Application
		Icon=$DIR/$TOOL/$BIN/Icon/256x256/sublime-merge.png
		StartupWMClass=Sublime_merge
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=adb                   # minimal installation of android debugging bridge and sideload
install_adb() {
	local url version
	{	url='https://dl.google.com/android/repository/platform-tools-latest-linux.zip' && \
		wget $url -O $TOOL.zip && unzip -q $TOOL.zip && rm $TOOL.zip && \
		version=$(platform-tools*/adb version | grep -F version | cut -d ' ' -f 5) && \
		mv platform-tools* $version && \
		ln -sfn $version latest && \
		BIN=latest && \
		return 0
	} || return 1
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=conda                 # root less package control software
install_conda() {
	unset BIN
	local url version
	{	url='https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh' && \
		wget $url -O miniconda.sh && \
		version=$(bash miniconda.sh -h | grep -F Installs | cut -d ' ' -f 3) && \
		rm -rf $version && \
		bash miniconda.sh -b -f -p $version && \
		ln -sfn $version latest && \
		BIN=latest/condabin && \
		return 0
	} || return 1
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=conda-dev             # setup dev env via conda. perl + packages , r + packages, rstudio, datamash, gcc, pigz, htslib
install_conda-dev() {
	[[ -n $CONDA_PREFIX ]] || die 'please activate conda first'
	local name="py3_dev_$(date +%F)"
	conda env remove -n $name || die 'please switch to base environment'
	conda config --set changeps1 False
	# macs2, tophat2/hisat2 and R stuff needs python2 whereas cutadapt,idr,rseqc need python3 env
	{	conda create -y -n $name python=3 && \
		conda install -n $name -y --override-channels -c iuc -c conda-forge -c bioconda -c main -c defaults -c r -c anaconda \
			gcc_linux-64 make automake xz zlib bzip2 pigz pbzip2 ncurses htslib ghostscript datamash \
			perl perl-threaded perl-dbi perl-app-cpanminus perl-bioperl perl-bio-eutilities \
			rstudio r-devtools bioconductor-biocinstaller bioconductor-biocparallel bioconductor-genefilter bioconductor-deseq2 \
			r-dplyr r-ggplot2 r-gplots r-rcolorbrewer r-svglite r-pheatmap r-ggpubr r-tidyverse r-data.table && \
		conda clean -y -a && \
		FOUND=true && \
		return 0
	} || return 1
}
[[ $OPT == $TOOL ]] && install_$TOOL # do not call run install_ to avoid mkdir - thus set FOUND manually to true

TOOL=perl-packages         # cpanminus + Try::Tiny List::MoreUtils DB_File Bio::Perl Bio::DB::EUtilities Tree::Simple XML::Simple
install_perl-packages() {
	# XML::Parser requires expat
	local url version
	{	url='cpanmin.us' && \
		wget $url -O cpanm && chmod 755 cpanm && \
		version=$(./cpanm -v 2>&1 | head -1 | perl -lane '$_=~/(\d[\d.]+)/; print $1') && \
		mv cpanm cpanm_$version && \
		ln -sfn cpanm_$version cpanm && \
		mkdir -p src && \
		./cpanm -l /dev/null --force --scandeps --save-dists $PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple && \
		./cpanm -l $PWD --reinstall --mirror file://$PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple && \
		return 0
	} || return 1
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=htop                  # graphical task manager
install_htop() {
	local url version
	{	version=$(curl -s http://hisham.hm/htop/releases/ | grep -Eo '^\s*<a href="[^"]+' | sed -r 's/\s*<a href="([^\/]+)\//\1/' | sort -V | tail -1) && \
		url="http://hisham.hm/htop/releases/$version/htop-$version.tar.gz" && \
		wget $url -O $TOOL.tar.gz && tar -xzf $TOOL.tar.gz && rm $TOOL.tar.gz && \
		rm -rf $version && mv htop* $version && \
		cd $version && \
		./configure --prefix=$PWD && \
		make -j $THREADS && \
		make install && \
		cd .. && \
		ln -sfn $version latest && \
		BIN=latest/bin && \
		return 0
	} || return 1
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=jabref                # references/citations manager
install_jabref() {
	local url version
	{	url='https://www.fosshub.com/JabRef.html'/$(curl -s https://www.fosshub.com/JabRef.html | grep -m 1 -ioE 'jabref-[0-9\.]+jar') && \
		version=$(basename $url .jar | cut -d '-' -f 2-) && \
		rm -rf $version && mkdir -p $version && \
		cd $version && \
		wget $url -O jabref.jar && \
		mkdir -p bin && \
		javawrapper bin/jabref $PWD/jabref.jar && \
		cd .. && \
		ln -sfn $version/bin latest && \
		BIN=latest && \
		return 0
	} || return 1
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=igv                   # !!! needs java 11 (setup -i java). interactive genome viewer
install_igv() {
	local url version
	{	url=$(curl -s https://software.broadinstitute.org/software/igv/download | grep -Eo 'href="[^"]+\.zip' | grep -vF -e Linux -e app.zip | cut -d '"' -f 2) && \
		version=$(basename $url .zip | cut -d '_' -f 2-) && \
		rm -rf $version && \
		wget $url -O $TOOL.zip && unzip -q $TOOL.zip && rm $TOOL.zip && \
		mv IGV* $version && \
		cd $version && \
		mem=$(grep -F -i memavailable /proc/meminfo | awk '{printf("%d",$2*0.8/1024/1024)}') && \
		sed -i -r "s/-Xmx\S+/-Xmx${mem}g/" igv.sh && \
		mkdir -p bin && \
	    sed -i 's/readlink[^$]/readlink -f /' igv.sh && \
		cd bin && \
		ln -sfn ../igv.sh igv && \
		cd ../.. && \
		ln -sfn $version/bin latest && \
		BIN=latest && \
		return 0
	} || return 1
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=tilix                 # best terminal emulator
install_tilix() {
	local url version
	{	url='https://github.com/gnunn1/tilix/releases/'$(curl -s https://github.com/gnunn1/tilix/releases/ | grep -oP 'download\/.+/tilix.zip' | sort -V | tail -1) && \
		version=$(basename $(dirname $url)) && \
		rm -rf $version && mkdir -p $version && \
		cd $version  && \
		wget $url -O $TOOL.zip && unzip -q $TOOL.zip && rm $TOOL.zip && \
		mv usr/* . && rm -rf usr && \
		glib-compile-schemas share/glib-*/schemas/
		touch bin/tilix.sh && \
		chmod 755 bin/* && \
		inkscape -D -w 256 -h 256 -e share/icons/hicolor/icon.png share/icons/hicolor/scalable/apps/com.gexperts.Tilix.svg && \
		cd .. && \
		ln -sfn $version latest && \
		BIN=latest/bin
	} || return 1
	cat <<- EOF > $DIR/$TOOL/$version/bin/tilix.sh || return 1
		#!/usr/bin/env bash
		export XDG_DATA_DIRS=\$XDG_DATA_DIRS:$DIR/$TOOL/$version/share
		export GSETTINGS_SCHEMA_DIR=\$GSETTINGS_SCHEMA_DIR:$DIR/$TOOL/$version/share/glib-2.0/schemas
		source /etc/profile.d/vte.sh
		$DIR/$TOOL/$version/bin/tilix
	EOF
	cat <<- EOF > $HOME/.local/share/applications/my-tilix.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Tilix
		Exec=$DIR/$TOOL/latest/bin/tilix.sh
		Icon=$DIR/$TOOL/latest/share/icons/hicolor/icon.png
		Type=Application
		StartupWMClass=Tilix
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=meld                  # compare files
install_meld() {
	local url version
	{	url=$(curl -s http://meldmerge.org/ | grep -Eo '^\s*<a href="[^"]+' | grep sources | sed -r 's/\s*<a href="//' | sort -V | tail -1) && \
		version=$(basename $(dirname $url)) && \
		wget $url -O $TOOL.tar.xz && tar -xf $TOOL.tar.xz && rm $TOOL.tar.xz && \
		rm -rf $version && \
		mv meld* $version && \
		ln -sfn $version latest && \
		BIN=latest/bin && \
		return 0
	} || return 1
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=spotify               # spotify - may need sudo ln -sf /usr/lib64/libcurl.so.4 /usr/lib64/libcurl-gnutls.so.4
install_spotify() {
	local url version
	{	url='https://repository-origin.spotify.com/pool/non-free/s/spotify-client/'$(curl -s https://repository-origin.spotify.com/pool/non-free/s/spotify-client/ | grep -oE 'spotify-client[^"]+_amd64.deb' | sort -V | tail -1)
		version=$(basename $url | cut -d '_' -f 2)
		version=${version%.*}
		wget $url -O $TOOL.deb && ar p $TOOL.deb data.tar.gz | tar xz && rm $TOOL.deb && \
		rm -rf $version  && mv usr/share/spotify $version && rm -rf usr && rm -rf etc && \
		ln -sfn $version latest && \
		BIN=latest
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-spotify.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Spotify
		Exec=$DIR/$TOOL/latest/spotify
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/spotify-linux-256.png
		StartupWMClass=Spotify
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

TOOL=skype                 # !!! may fail to be installed on some systems
install_skype() {
	local url
	{	url='https://go.skype.com/skypeforlinux-64.deb' && \
		wget $url -O $TOOL.deb && ar p $TOOL.deb data.tar.xz | tar xJ && rm $TOOL.deb && \
		rm -rf opt latest && \
		mv usr latest && \
		BIN=latest/bin
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-skype.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Skype
		Exec=$DIR/$TOOL/$BIN/skypeforlinux
		Type=Application
		Icon=$DIR/$TOOL/latest/share/icons/hicolor/256x256/apps/skypeforlinux.png
		StartupWMClass=Skype
	EOF
	return 0
}
[[ $OPT == 'all' ]] || [[ $OPT == $TOOL ]] && run install_$TOOL

${FOUND:=false} && {
	cat <<- EOF
		:INFO: success
		:INFO: to load tools read usage INFO section! execute '$(basename $0) -h'
	EOF
} || {
	die "$OPT not found"
}
