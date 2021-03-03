#! /usr/bin/env bash
# (c) Konstantin Riege
set -E -o pipefail -o functrace
shopt -s extdebug
shopt -s extglob
shopt -s expand_aliases
ulimit -n $(ulimit -Hn)
WDIR="$PWD"

printerr(){
	local OPTIND arg fun src lineno error cmd ex
	while getopts 'f:s:l:e:x:' arg; do
		case $arg in
			f) fun="$OPTARG";;
			s) src=$(readlink -e "$WDIR/$OPTARG");;
			l) lineno=$OPTARG;;
			e) error="$OPTARG";;
			x) ex=$OPTARG;;
			*) return 1;;
		esac
	done

	[[ $fun ]] && {
		local line
		read -r fun line src < <(declare -F "$fun") # requires shopt -s extdebug
		[[ $- =~ i ]] && ((lineno+=line))
	}
	local cmd=$(cd $WDIR; awk -v l=$lineno '{ if(NR>=l){if($0~/\s\\\s*$/){o=o$0}else{print o$0; exit}}else{if($0~/\s\\\s*$/){o=o$0}else{o=""}}}' $src | sed -E -e 's/\s+/ /g' -e 's/(^\s+|\s+$)//g')
	[[ $fun ]] && src="$src ($fun)"

	echo ":ERROR: ${error:-"..an unexpected one"} (exit $ex) @ $src @ line $lineno @ $cmd" 1>&2
	return 0
}

trap '
	pids=($(pstree -p $$ | grep -Eo "\([0-9]+\)" | grep -Eo "[0-9]+" | tail -n +2))
	{ kill -KILL "${pids[@]}" && wait "${pids[@]}"; } &> /dev/null
	printf "\r"
' EXIT

# must not be splitted into multiple lines to keep valid LINENO
trap 'e=$?;	if [[ $e -ne 141 ]]; then if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then printerr -x $e -e "$ERROR" -l $LINENO -s "$0"; exit $e; else printerr -x $e -e "$ERROR" -l $LINENO -f "${FUNCNAME[0]}"; return $e; fi; fi' ERR

trap 'declare -F _cleanup::${FUNCNAME[0]} &> /dev/null && _cleanup::${FUNCNAME[0]}' RETURN

trap 'ERROR="killed"' INT TERM

############### GLOBAL VARS ###############

DIR=$HOME/programs
SOURCE=$DIR/SOURCE.me
THREADS=$(cat /proc/cpuinfo | grep -cF processor)
ERROR="..an unexpected one"
declare -A OPT=([all]=1)
export MAKEFLAGS="-j $THREADS"

############### FUNCTIONS ###############

usage(){
	local tools=$(grep '^TOOL=' $0 | cut -d '=' -f 2)
	cat <<- EOF
		DESCRIPTION
		bare-system-basics brings software locally to your linux computer
		!!! we <3 space-free file-paths !!!

		VERSION
		0.4.4

		SYNOPSIS
		$(basename $0) -i [tool]

		OPTIONS
		-h | --help           # prints this message
		-d | --dir [path]     # installation path - default: $DIR
		-t | --threads [num]  # threads to use for comilation - default: $THREADS
		-i | --install [tool] # tool(s) to install/update (comma seperated, see below) - default: "all"
		                      # all means except cronjob, skype, conda-env, r-libs, perl-libs and python-libs
		                      # hint1: activate recently installed conda base environment to install conda-env in a second round
		                      # hint2: activate the setupped conda py3_dev_<date> environment to install libraries in a third round

		TOOLS
		$tools

		INFO
		1) how to use conda tools and non-conda libraries
		- to load conda itself, execute 'source $DIR/conda/latest/bin/activate'
		- to list and load a conda environment execute 'conda info -e' and 'conda activate [env]'
		- to load non-conda installed perl packages execute 'export PERL5LIB=$DIR/perl-libs/<version>/lib/perl5'
		- to load non-conda installed r packages execute 'export R_LIBS=$DIR/r-libs/<version>'
		- to load non-conda installed python packages execute 'export PYTHONPATH=$DIR/python-libs/<version>'


		2) to define a tool as default application
		- adapt ~/.config/mimeapps.list
		- adapt ~/.local/share/applications/mimeapps.list

		3) in case of onlyoffice displaying/scaling issues
		- adjust QT settings in ~/.local/share/applications/my-onlyoffice.desktop

		4) in case of not properly grouped windows in gnome application dock
		- look for StartupWMClass in .desktop file
		- assign on of the values shown by executing 'xprop WM_CLASS' + mouse-click on window

		REFERENCES
		(c) Konstantin Riege
	EOF
	exit 0
}

checkopt(){
	local arg=false
	case $1 in
		-h | --h | -help | --help) usage;;
		-t | --t | -threads | --threads) arg=true; THREADS=$2;;
		-i | --i | -install | --install) arg=true; OPT=(); mapfile -t -d ',' -t < <(printf '%s' "$2"); for t in "${MAPFILE[@]}"; do OPT[$t]=1; done;;
		-d | --d | -dir | --dir) arg=true; DIR=$2; SOURCE=$DIR/SOURCE.me; ERROR='check your installation path'; mkdir -p $DIR;;
		-*) ERROR="illegal option $1"; return 1;;
		*) ERROR="illegal option $2"; return 1;;
	esac
	if $arg; then
		[[ ! $2 ]] && ERROR="argument missing for option $1" && return 1
		[[ "$2" =~ ^- ]] && ERROR="illegal argument $2 for option $1" && return 1
	else
		[[ $2 ]] && [[ ! "$2" =~ ^- ]] && ERROR="illegal argument $2 for option $1" && return 1
	fi
	return 0
}

run(){
	FOUND=true
	unset BIN
	ERROR="failed during setup of $TOOL"
	mkdir -p $DIR/$TOOL
	cd $DIR/$TOOL
	$1

	# adapt source
	touch $SOURCE
	[[ $BIN ]] && {
		sed -i "/PATH=/d" $SOURCE
		sed -i "\@$DIR/$TOOL@d" $SOURCE #\@ necessary for path matches - s@/dir/path/@replacement@ is okay , @/dir/path/@d not
		grep -q -m 1 -F "VAR=" $SOURCE && echo "VAR=\$VAR:$DIR/$TOOL/$BIN" >> $SOURCE || echo "VAR=$DIR/$TOOL/$BIN" >> $SOURCE
		echo 'PATH=$VAR:$PATH' >> $SOURCE
	}
	return 0
}

javawrapper() {
	local java=java
	[[ $3 ]] && java="$3"
	cat <<- EOF > "$1"
		#!/usr/bin/env bash
		java=$java
		[[ \$JAVA_HOME && -e "\$JAVA_HOME/bin/java" ]] && java="\$JAVA_HOME/bin/java"
		declare -a jvm_mem_args jvm_prop_args pass_args
		for arg in \$@; do
			case \$arg in
				-D*) jvm_prop_args+=("\$arg");;
				-XX*) jvm_prop_args+=("\$arg");;
				-Xm*) jvm_mem_args+=("\$arg");;
				*) pass_args+=("\$arg");;
			esac
		done
		[[ ! \$jvm_mem_args ]] && jvm_mem_args+=("-Xms1024m") && jvm_mem_args+=("-Xmx4g")
		exec "\$java" "\${jvm_mem_args[@]}" "\${jvm_prop_args[@]}" -jar "$2" "\${pass_args[@]}"
	EOF
	chmod 755 "$1"
	return 0
}

############### MAIN ###############

[[ $# -eq 0 ]] && usage
ERROR="illegal option $1"
[[ $# -eq 1 ]] && [[ $1 =~ ^- ]]
for i in $(seq 1 $#); do
	if [[ ${!i} =~ ^- ]]; then
		j=$((i+1))
		checkopt "${!i}" "${!j}"
	else
		((++i))
	fi
done
unset ERROR

TOOL=cronjob               # setup a cron job file to update all softare once a month
install_cronjob(){
	local src="$(readlink -e "$WDIR/$0")"
	# <minute> <hour> <day of month> <month> <day of week> <command>
	echo "0 0 1 * * $src -i all -d $DIR -t $THREADS" > "$(dirname "$src")/cron.job"

	FOUND=true
	return 0
}
[[ ${OPT[$TOOL]} ]] && install_$TOOL # do not call run install_ to avoid mkdir - thus set FOUND manually to true

TOOL=google-chrome         # google chrome webbrowser
install_google-chrome(){
	_cleanup::install_google-chrome(){
		rm -f $TOOL.deb
	}

	local url version
	url='https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb
	ar p $TOOL.deb data.tar.xz | tar xJ && rm -f $TOOL.deb
	version=$(opt/google/chrome/google-chrome --version | awk '{print $NF}')
	rm -rf $version && mv opt $version && rm -rf usr && rm -rf etc
	ln -sfnr $version latest
	BIN=latest/google/chrome

	cat <<- EOF > $HOME/.local/share/applications/my-chrome.desktop
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
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=vivaldi               # sophisticated chrome based webbrowser - highly recommended :)
install_vivaldi(){
	_cleanup::install_vivaldi(){
		rm -f $TOOL.deb
	}

	local url version
	url=$(curl -s https://vivaldi.com/download/archive/?platform=linux | grep -Eo 'http[^"]+vivaldi-stable_[^"]+amd64\.deb' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/vivaldi-stable_([0-9\.]+).+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb
	rm -rf $version
	ar p $TOOL.deb data.tar.xz | tar xJ && rm -f $TOOL.deb
	mv opt $version && rm -rf usr && rm -rf etc
	ln -sfnr $version latest
	BIN=latest/vivaldi

	cat <<- EOF > $HOME/.local/share/applications/my-vivaldi.desktop
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
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=opera                 # chrome based webbrowser with vpn
install_opera(){
	_cleanup::install_opera(){
		rm -f $TOOL.deb
	}

	local url version
	url='https://get.geo.opera.com/pub/opera/desktop/'
	version=$(curl -s $url | grep -oE 'href="[0-9]+[0-9\.]+' | cut -d '"' -f 2 | sort -Vr | head -1)
	url="$url$version/linux/opera-stable_${version}_amd64.deb"
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb
	rm -rf $version
	ar p $TOOL.deb data.tar.xz | tar xJ && rm -f $TOOL.deb
	mv usr $version
	ln -sfnr $version latest
	BIN=latest/bin

	cat <<- EOF > $HOME/.local/share/applications/my-opera.desktop
		[Desktop Entry]
		Terminal=false
		Name=Opera
		Exec=$DIR/$TOOL/$BIN/opera %U
		Type=Application
		Icon=$DIR/$TOOL/latest/share/icons/hicolor/256x256/apps/opera.png
		StartupWMClass=Opera
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=firefox               # updates via interface possible. firefox webbrowser
install_firefox(){
	_cleanup::install_opera(){
		rm -f $TOOL.tar.bz2
	}

	local url version
	url='https://ftp.mozilla.org/pub/firefox/releases/'
	version=$(curl -s $url | grep -oE 'releases/[0-9\.]+' | cut -d '/' -f 2 | sort -Vr | head -1)
	url="$url$version/linux-x86_64/en-US/firefox-$version.tar.bz2"
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.bz2
	rm -rf $version
	tar -xjf $TOOL.tar.bz2 && rm -f $TOOL.tar.bz2
	mv firefox* $version
	ln -sfnr $version latest
	BIN=latest

	cat <<- EOF > $HOME/.local/share/applications/my-firefox.desktop
		[Desktop Entry]
		Name=Firefox
		Exec=$DIR/$TOOL/$BIN/firefox %U
		Icon=$DIR/$TOOL/$BIN/browser/chrome/icons/default/default128.png
		Terminal=false
		Type=Application
		StartupWMClass=Firefox
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=thunderbird           # updates itself. thunderbird email tool - best until vivaldi m3 is released
install_thunderbird(){
	_cleanup::install_thunderbird(){
		rm -f $TOOL.tar.bz2
	}

	local url version
	url='https://ftp.mozilla.org/pub/thunderbird/releases/'
	version=$(curl -s $url | grep -oE 'releases/[0-9\.]+' | cut -d '/' -f 2 | sort -Vr | head -1)
	url="$url$version/linux-x86_64/en-US/thunderbird-$version.tar.bz2"
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.bz2
	rm -rf $version
	tar -xjf $TOOL.tar.bz2 && rm -f $TOOL.tar.bz2
	mv thunderbird* $version
	ln -sfnr $version latest
	BIN=latest

	cat <<- EOF > $HOME/.local/share/applications/my-thunderbird.desktop
		[Desktop Entry]
		Terminal=false
		Name=Thunderbird
		Exec=$DIR/$TOOL/$BIN/thunderbird %U
		Type=Application
		Icon=$DIR/$TOOL/$BIN/chrome/icons/default/default128.png
		StartupWMClass=Thunderbird
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=keeweb                # keepass db compatible password manager with cloud sync support
install_keeweb(){
	_cleanup::install_keeweb(){
		rm -f $TOOL.zip
	}

	local url version
	url='https://github.com/'$(curl -s https://github.com/keeweb/keeweb/releases | grep -oE 'keeweb/\S+KeeWeb-[0-9\.]+\.linux\.x64\.zip' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/KeeWeb-([0-9\.]+)\..+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.zip
	rm -rf $version && mkdir $version
	unzip -q $TOOL.zip -d $version && rm -f $TOOL.zip
	ln -sfnr $version latest
	BIN=latest

	cat <<- EOF > $HOME/.local/share/applications/my-keeweb.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=KeeWeb
		Exec=$DIR/$TOOL/$BIN/keeweb
		Type=Application
		Icon=$DIR/$TOOL/$BIN/128x128.png
		StartupWMClass=KeeWeb
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=java                  # oracle java runtime and development kit
install_java(){
	_cleanup::install_java(){
		rm -f $TOOL.tar.gz
	}

	local url version
	#url="https://download.oracle.com/otn-pub/java/jdk/15.0.1%2B9/51f4f36ad4ef43e39d0dfdbaf6549e32/jdk-15.0.1_linux-x64_bin.tar.gz"
	url="https://download.oracle.com/otn-pub/java/jdk/15.0.2%2B7/0d1cfde4252546c6931946de8db48ee2/jdk-15.0.2_linux-x64_bin.tar.gz"
	version=$(basename $url | sed -E 's/jdk-([0-9\.]+).+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" $url -O $TOOL.tar.gz
	rm -rf $version
	tar -xzf $TOOL.tar.gz && rm -f $TOOL.tar.gz
	mv jdk* $version
	ln -sfnr $version latest
	BIN=latest/bin
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=pdf-editor4           # master pdf viewer and editor v4 (latest without watermark)
install_pdf-editor4(){
	_cleanup::install_pdf-editor4(){
		rm -f $TOOL.tar.gz
	}

	local url version
	url='http://code-industry.net/public/master-pdf-editor-4.3.89_qt5.amd64.tar.gz'
	version=$(basename $url | sed -E 's/master-pdf-editor-([0-9\.]+).+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz
	rm -rf $version
	tar -xzf $TOOL.tar.gz && rm -f $TOOL.tar.gz
	mv master-pdf-editor* $version
	ln -sfnr $version latest
	BIN=latest

	cat <<- EOF > $HOME/.local/share/applications/my-masterpdfeditor4.desktop
		[Desktop Entry]
		Terminal=false
		Name=Masterpdfeditor4
		Exec=$DIR/$TOOL/$BIN/masterpdfeditor4 %U
		Type=Application
		Icon=$DIR/$TOOL/$BIN/masterpdfeditor4.png
		StartupWMClass=Masterpdfeditor4
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=pdf-editor5           # master pdf viewer and editor v5
install_pdf-editor5(){
	_cleanup::install_pdf-editor4(){
		rm -f $TOOL.tar.gz
	}

	local url version
	url=$(curl -s https://code-industry.net/free-pdf-editor/ | grep -oE 'http\S+qt5\S+\.tar\.gz')
	version=$(basename $url | sed -E 's/master-pdf-editor-([0-9\.]+).+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz
	rm -rf $version
	tar -xzf $TOOL.tar.gz && rm -f $TOOL.tar.gz
	mv master-pdf-editor* $version
	ln -sfnr $version latest
	BIN=latest

	cat <<- EOF > $HOME/.local/share/applications/my-masterpdfeditor5.desktop
		[Desktop Entry]
		Terminal=false
		Name=Masterpdfeditor5
		Exec=$DIR/$TOOL/$BIN/masterpdfeditor5 %U
		Type=Application
		Icon=$DIR/$TOOL/$BIN/masterpdfeditor5.png
		StartupWMClass=Masterpdfeditor5
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=sublime               # very powerful text editor and integrated developer environment for all languages
install_sublime(){
	_cleanup::install_sublime(){
		rm -f $TOOL.tar.bz2
	}

	local url version
	url=$(curl -s  https://www.sublimetext.com/3 | grep -Eo 'http\S+x64\.tar\.bz2' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/.+build_([0-9\.]+).+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.bz2
	rm -rf $version
	tar -xjf $TOOL.tar.bz2 && rm -f $TOOL.tar.bz2
	mv sublime* $version
	mkdir -p $version/bin
	ln -sfnr $version/sublime_text $version/bin/subl
	ln -sfnr $version/sublime_text $version/bin/
	ln -sfnr $version latest
	BIN=latest/bin

	cat <<- EOF > $HOME/.local/share/applications/my-sublime.desktop
		[Desktop Entry]
		Terminal=false
		Name=Sublime
		Exec=$DIR/$TOOL/$BIN/sublime_text %U
		Type=Application
		Icon=$DIR/$TOOL/latest/Icon/256x256/sublime-text.png
		StartupWMClass=Sublime_text
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=sublime-merge         # very powerful git client
install_sublime-merge(){
	_cleanup::install_sublime-merge(){
		rm -f $TOOL.tar.xz
	}

	local url version
	url=$(curl -s https://www.sublimemerge.com/download | grep -oE 'http\S+x64\.tar\.xz' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/.+build_([0-9\.]+).+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.xz
	rm -rf $version
	tar -xf $TOOL.tar.xz && rm -f $TOOL.tar.xz
	mv sublime* $version
	mkdir -p $version/bin
	ln -sfnr $version/sublime_merge $version/bin/sublmerge
	ln -sfnr $version/sublime_merge $version/bin/
	ln -sfnr $version latest
	BIN=latest/bin

	cat <<- EOF > $HOME/.local/share/applications/my-sublime-merge.desktop
		[Desktop Entry]
		Terminal=false
		Name=Sublime Merge
		Exec=$DIR/$TOOL/$BIN/sublime_merge
		Type=Application
		Icon=$DIR/$TOOL/latest/Icon/256x256/sublime-merge.png
		StartupWMClass=Sublime_merge
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=adb                   # minimal installation of android debugging bridge and sideload
install_adb(){
	_cleanup::install_adb(){
		rm -f $TOOL.zip
	}

	local url version
	url='https://dl.google.com/android/repository/platform-tools-latest-linux.zip'
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.zip
	unzip -q $TOOL.zip && rm -f $TOOL.zip
	version=$(platform-tools*/adb version | grep -F version | cut -d ' ' -f 5)
	rm -rf $version
	mv platform-tools* $version
	ln -sfnr $version latest
	BIN=latest
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=conda                 # root less package control software
install_conda(){
	_cleanup::install_conda(){
		rm -f miniconda.sh
	}

	unset BIN
	local url version
	url='https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh'
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O miniconda.sh
	version=$({ bash miniconda.sh -h || true; } | grep -F Installs | cut -d ' ' -f 3)
	rm -rf $version
	bash miniconda.sh -b -f -p $version
	ln -sfnr $version latest
	BIN=latest/condabin
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=conda-env             # setup dev env via conda. compilers, perl + packages ,r-base , curl, datamash, ghostscript, pigz, htslib
install_conda-env(){
	ERROR='please activate conda first'
	[[ -n $CONDA_PREFIX ]] || false
	local name="py3_dev_$(date +%F)"
	ERROR='please switch to base environment'
	conda env remove -y -n $name || false
	unset ERROR
	conda config --set changeps1 False

	# for py2 env: perl-libs XML::Parser requires expat, Bio::Perl requires perl-dbi perl-db-file
	# -> in py3 env self compiling perl modules is terrifying

	# r-libs ggpubr requires nlopt
	# do not install r-studio which is old and in r channel only plus depends on old r channel r-base whereas r-base in conda-forge is actively maintained
	# thus, when using conda rstudio there will be clashes of r channel r-base version and other channel libraries r built versions
	# -> freeze r-base version known to have all requested modules available
	# perl from conda-forge is compiled with threads, perl from bioconda not (recently removed) - thus there is an old perl-threaded version
	conda create -y -n $name python=3
	conda install -n $name -y --override-channels -c iuc -c conda-forge -c bioconda -c main -c defaults -c r -c anaconda \
		gcc_linux-64 gxx_linux-64 gfortran_linux-64 \
		glib pkg-config make automake cmake \
		bzip2 pigz pbzip2 \
		curl ghostscript dos2unix datamash \
		htslib expat nlopt \
		perl perl-app-cpanminus perl-list-moreutils perl-try-tiny perl-dbi perl-db-file perl-xml-parser perl-bioperl perl-bio-eutilities \
		r-base=4.0.2 \
		java-jdk
	conda clean -y -a
	source $CONDA_PREFIX/bin/activate $name
	cpanm Switch

	FOUND=true
	return 0
}
[[ ${OPT[$TOOL]} ]] && install_$TOOL # do not call run install_ to avoid mkdir - thus set FOUND manually to true

TOOL=python-libs           # conda/non-conda: numpy scipy pysam cython matplotlib
install_python-libs(){
	mkdir -p src
	if [[ $CONDA_PREFIX && $(conda env list | awk '$2=="*"{print $1}') != "base" ]]; then
		pip download -d $PWD/src numpy scipy pysam cython matplotlib
		pip install --force-reinstall --find-links $PWD/src numpy scipy pysam cython matplotlib
	else
		local x url
		read -r -p ':WARNING: current environment may not fulfill all prerequisites and dependencies. please try with an activated conda environment or continue? (y|n): ' x
		[[ $x == "n" ]] && return 0
		version=$(python --version | awk '{print $NF}')
		mkdir -p $version
		pip download -d $PWD/src numpy scipy pysam cython matplotlib
		pip install --force-reinstall --prefix $PWD/$version --find-links $PWD/src numpy scipy pysam cython matplotlib
	fi
	return 0
}
[[ ${OPT[$TOOL]} ]] && run install_$TOOL # do not call run install_ to avoid mkdir - thus set FOUND manually to true

TOOL=r-libs                # conda/non-conda: dplyr tidyverse ggpubr ggplot2 gplots RColorBrewer svglite pheatmap data.table BiocParallel genefilter DESeq2 DEXSeq clusterProfiler TCGAutils TCGAbiolinks WGCNA DGCA
install_r-libs(){
	mkdir -p src
	# packages from cran - needs to be last since e.g. WGCNA depends on bioconductor packages
	# R-Forge.r does not complaine about knapsack not being compatible with R>=4
	if [[ $CONDA_PREFIX && $(conda env list | awk '$2=="*"{print $1}') != "base" ]]; then
		Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages(c('devtools','codetools'), repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src')"
		if [[ $(conda list -f r-base | tail -1 | awk '$2<3.5{print "legacy"}') ]]; then
			Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); source('https://bioconductor.org/biocLite.R'); BiocInstaller::biocLite(c('BiocParallel','genefilter','DESeq2','DEXSeq','clusterProfiler','TCGAutils','TCGAbiolinks','survminer','impute','preprocessCore','GO.db','AnnotationDbi'), ask=F, Ncpus=$THREADS, clean=T, destdir='$PWD/src')"
		else
			Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages('BiocManager', repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src')"
			Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); BiocManager::install(c('BiocParallel','genefilter','DESeq2','DEXSeq','clusterProfiler','TCGAutils','TCGAbiolinks','survminer','impute','preprocessCore','GO.db','AnnotationDbi'), ask=F, Ncpus=$THREADS, clean=T, destdir='$PWD/src')"
		fi
		Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages(c('reshape2','WGCNA','dplyr','tidyverse','ggpubr','ggplot2','gplots','RColorBrewer','svglite','pheatmap','data.table'), repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src')"
		Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages(c('knapsack'), repos='http://R-Forge.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src')"
		Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); devtools::install_github(c('andymckenzie/DGCA'), upgrade='never', force=T, clean=T, destdir='$PWD/src')"
	else
		local x version
		read -r -p ':WARNING: current environment may not fulfill all prerequisites and dependencies. please try with an activated conda environment or continue? (y|n): ' x
		[[ $x == "n" ]] && return 0
		version=$(Rscript --version 2>&1 | awk '{print $(NF-1)}')
		mkdir -p $version
		Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages(c('devtools','codetools'), repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')"
		if [[ $(conda list -f r-base | tail -1 | awk '$2<3.5{print "legacy"}') ]]; then
			Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); source('https://bioconductor.org/biocLite.R'); BiocInstaller::biocLite(c('BiocParallel','genefilter','DESeq2','DEXSeq','clusterProfiler','TCGAutils','TCGAbiolinks','survminer','impute','preprocessCore','GO.db','AnnotationDbi'), ask=F, Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')"
		else
			Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages('BiocManager', repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')"
			Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); BiocManager::install(c('BiocParallel','genefilter','DESeq2','DEXSeq','clusterProfiler','TCGAutils','TCGAbiolinks','survminer','impute','preprocessCore','GO.db','AnnotationDbi')), ask=F, Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')"
		fi
		Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages(c('dplyr','tidyverse','ggpubr','ggplot2','gplots','RColorBrewer','svglite','pheatmap','data.table'), repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')"
		Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages(c('knapsack'), repos='http://R-Forge.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')"
		Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); devtools::install_github(c('andymckenzie/DGCA'), upgrade='never', force=T, clean=T, destdir='$PWD/src', lib='$PWD/$version')"
	fi
	return 0
}
[[ ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=perl-libs             # conda/non-conda: Try::Tiny List::MoreUtils DB_File Bio::Perl Bio::DB::EUtilities Tree::Simple XML::Simple
install_perl-libs(){
	mkdir -p src
	local x url
	if [[ $CONDA_PREFIX && $(conda env list | awk '$2=="*"{print $1}') != "base" ]]; then
		[[ $($CONDA_PYTHON_EXE --version | awk '{printf "%d",$NF}') -eq 3 ]] && {
			read -r -p ':WARNING: already installed! furthermore, current conda environment may not fulfill all prerequisites and dependencies for compilation form source. continue ?(y|n): ' x
			[[ $x == "n" ]] && return 0
		}
		# CFLAGS="-I$CONDA_PREFIX/include"
		# LDFLAGS="-L$CONDA_PREFIX/lib"
		# CPATH="$CONDA_PREFIX/include"
		# LIBRARY_PATH="$CONDA_PREFIX/lib"
		# LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
		env EXPATINCPATH="$CONDA_PREFIX/include" EXPATLIBPATH="$CONDA_PREFIX/lib" cpanm -l /dev/null --force --scandeps --save-dists $PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple
		env EXPATINCPATH="$CONDA_PREFIX/include" EXPATLIBPATH="$CONDA_PREFIX/lib" cpanm --reinstall --mirror file://$PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple
	else
		read -r -p ':WARNING: current environment may not fulfill all prerequisites and dependencies. please try with an activated conda environment or continue? (y|n): ' x
		[[ $x == "n" ]] && return 0
		version=$(perl --version | head -2 | tail -1 | sed -E 's/.+\(v(.+)\).+/\1/')
		mkdir -p $version
		url='c	panmin.us'
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O cpanm
		chmod 755 cpanm
		./cpanm -l /dev/null --force --scandeps --save-dists $PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple
		./cpanm -l $PWD/$version --reinstall --mirror file://$PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple
	fi
	return 0
}
[[ ${OPT[$TOOL]} ]] && run install_$TOOL # do not call run install_ to avoid mkdir - thus set FOUND manually to true

TOOL=htop                  # graphical task manager
install_htop(){
	_cleanup::install_htop(){
		rm -f $TOOL.tar.gz
	}

	local url version
	url='http://hisham.hm/htop/releases/'
	version=$(curl -s $url | grep -oE 'href="[0-9\.]+' | cut -d '"' -f 2 | sort -Vr | head -1)
	url="$url$version/htop-$version.tar.gz"
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz
	rm -rf $version
	tar -xzf $TOOL.tar.gz && rm -f $TOOL.tar.gz
	mkdir -p $version
	cd htop*
	./configure --prefix=$DIR/$TOOL/$version
	make -j $THREADS
	make install
	make clean
	cd ..
	rm -rf htop*
	ln -sfnr $version latest
	BIN=latest/bin
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=jabref                # references/citations manager
install_jabref(){
	_cleanup::install_jabref(){
		rm -f $TOOL.tar.gz
	}

	local url version
	url='https://github.com/'$(curl -s https://github.com/JabRef/jabref/releases | grep -oE 'JabRef/\S+JabRef-[0-9\.]+-portable_linux\.tar\.gz' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/JabRef-([0-9\.]+).+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz
	rm -rf $version
	tar -xzf $TOOL.tar.gz && rm -f $TOOL.tar.gz
	mv JabRef $version
	ln -sfnr $version latest
	BIN=latest/bin
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=igv                   # interactive genome viewer (needs java >=11)
install_igv(){
	_cleanup::install_igv(){
		rm -f $TOOL.zip
	}

	local url version
	url=$(curl -s https://software.broadinstitute.org/software/igv/download | grep -Eo 'http\S+IGV_[0-9\.]+\.zip' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/IGV_([0-9\.]+)\..+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.zip
	rm -rf $version
	unzip -q $TOOL.zip && rm -f $TOOL.zip
	mv IGV* $version
	mem=$(grep -F -i memavailable /proc/meminfo | awk '{printf("%d",$2*0.8/1024/1024)}')
	sed -i -r "s/-Xmx\S+/-Xmx${mem}g/" $version/igv.sh
	sed -i 's/readlink[^$]/readlink -f /' $version/igv.sh
	mkdir -p $version/bin
	ln -sfnr $version/igv.sh $version/bin/igv
	ln -sfnr $version latest
	BIN=latest/bin
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=tilix                 # best terminal emulator
install_tilix(){
	_cleanup::install_tilix(){
		rm -f $TOOL.zip
	}

	local url version
	url='https://github.com/'$(curl -s https://github.com/gnunn1/tilix/releases/ | grep -oE 'gnunn1\S+tilix\.zip' | sort -Vr | head -1)
	version=$(basename $(dirname $url))
	rm -rf $version && mkdir -p $version
	cd $version
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.zip
	unzip -q $TOOL.zip && rm -f $TOOL.zip
	mv usr/* . && rm -rf usr
	glib-compile-schemas share/glib-*/schemas/
	touch bin/tilix.sh
	chmod 755 bin/*
	inkscape -D -w 256 -h 256 -e share/icons/hicolor/icon.png share/icons/hicolor/scalable/apps/com.gexperts.Tilix.svg
	cd ..
	ln -sfnr $version latest
	BIN=latest/bin

	cat <<- EOF > $DIR/$TOOL/$version/bin/tilix.sh
		#!/usr/bin/env bash
		export XDG_DATA_DIRS="\${XDG_DATA_DIRS:+\$XDG_DATA_DIRS:}$DIR/$TOOL/$version/share"
		export GSETTINGS_SCHEMA_DIR="\${GSETTINGS_SCHEMA_DIR:+\$GSETTINGS_SCHEMA_DIR:}$DIR/$TOOL/$version/share/glib-2.0/schemas"
		source /etc/profile.d/vte.sh
		$DIR/$TOOL/$version/bin/tilix
	EOF
	cat <<- EOF > $HOME/.local/share/applications/my-tilix.desktop
		[Desktop Entry]
		Terminal=false
		Name=Tilix
		Exec=$DIR/$TOOL/$BIN/tilix.sh
		Icon=$DIR/$TOOL/latest/share/icons/hicolor/icon.png
		Type=Application
		StartupWMClass=Tilix
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=meld                  # nice way to compare files side by side
install_meld(){
	_cleanup::install_meld(){
		rm -f $TOOL.tar.xz
	}

	local url version
	url=$(curl -s http://meldmerge.org/ | grep -oE 'http\S+meld-[0-9\.]+\.tar\.xz' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/meld-([0-9\.]+)\..+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.xz
	rm -rf $version
	tar -xf $TOOL.tar.xz && rm -f $TOOL.tar.xz
	mv meld* $version
	ln -sfnr $version latest
	BIN=latest/bin
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=spotify               # spotify - may need sudo ln -sf /usr/lib64/libcurl.so.4 /usr/lib64/libcurl-gnutls.so.4
install_spotify(){
	_cleanup::install_spotify(){
		rm -f $TOOL.deb
	}

	local url version
	url='https://repository-origin.spotify.com/pool/non-free/s/spotify-client/'
	url="$url"$(curl -s "$url" | grep -oE 'spotify-client_[^"]+_amd64\.deb' | sort -Vr | head -1)
	version=$(basename "$url" | sed -E 's/spotify-client_([0-9\.]+)\..+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N "$url" -O $TOOL.deb
	rm -rf $version
	ar p $TOOL.deb data.tar.gz | tar xz && rm -f $TOOL.deb
	mv usr/share/spotify $version && rm -rf usr && rm -rf etc
	mkdir -p $version/bin
	ln -sfnr $version/spotify $version/bin/
	ln -sfnr $version latest
	BIN=latest/bin

	cat <<- EOF > $HOME/.local/share/applications/my-spotify.desktop
		[Desktop Entry]
		Terminal=false
		Name=Spotify
		Exec=$DIR/$TOOL/$BIN/spotify
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/spotify-linux-256.png
		StartupWMClass=Spotify
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=skype                 # !!! may fail to be installed on some systems
install_skype(){
	_cleanup::install_skype(){
		rm -f $TOOL.deb
	}

	local url
	url='https://go.skype.com/skypeforlinux-64.deb'
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb
	ar p $TOOL.deb data.tar.xz | tar xJ && rm -f $TOOL.deb
	rm -rf opt latest
	mv usr latest
	ln -sfnr latest/bin/skypeforlinux latest/bin/skype
	BIN=latest/bin

	cat <<- EOF > $HOME/.local/share/applications/my-skype.desktop
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
[[ ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=onlyoffice            # nice ms office clone
install_onlyoffice(){
	_cleanup::install_onlyoffice(){
		rm -f $TOOL.AppImage
	}

	local url
	url='http://download.onlyoffice.com/install/desktop/editors/linux/DesktopEditors-x86_64.AppImage'
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.AppImage
	chmod 755 $TOOL.AppImage
	version=$(./$TOOL.AppImage --version 2>&1 | tail -n 1 | rev | cut -d ' ' -f 1 | rev)
	rm -rf $version
	./$TOOL.AppImage --appimage-extract
	mv squashfs-root $version
	mkdir -p $version/bin
	ln -sfnr $version/AppRun $version/bin/onlyoffice
	ln -sfnr $version latest
	BIN=latest/bin

	cat <<- EOF > $HOME/.local/share/applications/my-onlyoffice.desktop
		[Desktop Entry]
		Terminal=false
		Name=Onlyoffice
		Exec=env QT_SCREEN_SCALE_FACTORS=1 QT_SCALE_FACTOR=0.5 $DIR/$TOOL/$BIN/onlyoffice --force-scale=1 %U
		Type=Application
		Icon=$DIR/$TOOL/latest/asc-de.png
		StartupWMClass=DesktopEditors
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=wpsoffice             # best ms office clone available - please check version/url update manually at http://linux.wps.com
install_wpsoffice(){
	_cleanup::install_wpsoffice(){
		rm -f $TOOL.deb
	}

	local url
	url='http://wdl1.pcfg.cache.wpscdn.com/wpsdl/wpsoffice/download/linux/9662/wps-office_11.1.0.9662.XA_amd64.deb'
	version=$(basename $url | sed -E 's/wps-office_([0-9\.]+)\..+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb
	rm -rf $version
	ar p $TOOL.deb data.tar.xz | tar xJ && rm -f $TOOL.deb
	mv opt/kingsoft/wps-office/office6 $version
	mv usr/share/icons/hicolor/512x512/mimetypes $version/icons
	mkdir -p $version/bin
	ln -sfnr $version/wps $version/bin/wps-write
	ln -sfnr $version/wpp $version/bin/wps-present
	ln -sfnr $version/wpspdf $version/bin/wps-pdf
	ln -sfnr $version/et $version/bin/wps-calc
	mkdir -p ~/.local/share/fonts
	mv usr/share/fonts/wps-office/* ~/.local/share/fonts
	rm -rf opt usr etc
	ln -sfnr $version latest
	BIN=latest/bin

	cat <<- EOF > $HOME/.local/share/applications/my-wpsoffice-write.desktop
		[Desktop Entry]
		Terminal=false
		Name=WPSoffice-Write
		Exec=$DIR/$TOOL/$BIN/wps-write %U
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/wps-office2019-wpsmain.png
		StartupWMClass=Wps-write
	EOF
	cat <<- EOF > $HOME/.local/share/applications/my-wpsoffice-present.desktop
		[Desktop Entry]
		Terminal=false
		Name=WPSoffice-Present
		Exec=$DIR/$TOOL/$BIN/wps-present %U
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/wps-office2019-wppmain.png
		StartupWMClass=Wps-present
	EOF
	cat <<- EOF > $HOME/.local/share/applications/my-wpsoffice-calc.desktop
		[Desktop Entry]
		Terminal=false
		Name=WPSoffice-Calc
		Exec=$DIR/$TOOL/$BIN/wps-calc %U
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/wps-office2019-etmain.png
		StartupWMClass=Wps-calc
	EOF
	cat <<- EOF > $HOME/.local/share/applications/my-wpsoffice-pdf.desktop
		[Desktop Entry]
		Terminal=false
		Name=WPSoffice-PDF
		Exec=$DIR/$TOOL/$BIN/wps-pdf %U
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/wps-office2019-pdfmain.png
		StartupWMClass=Wps-pdf
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=emacs                 # emacs rulez in non-evil doom mode or copy provided config to ~/.emacs
install_emacs(){
	_cleanup::install_emacs(){
		rm -f $TOOL.tar.gz
	}

	local url version tool
	url='http://ftp.gnu.org/gnu/emacs/'
	url="$url"$(curl -s $url | grep -oE 'emacs-[0-9\.]+\.tar\.gz' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/emacs-([0-9\.]+)\..+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz
	rm -rf $version
	tar -xzf $TOOL.tar.gz && rm -f $TOOL.tar.gz
	mkdir -p $version
	cd emacs*
	./configure --prefix=$DIR/$TOOL/$version --with-x-toolkit=no --with-xpm=ifavailable --with-gif=ifavailable
	make -j $THREADS
	make install
	make clean
	cd ..
	rm -rf emacs*
	ln -sfnr $version latest
	BIN=latest/bin

	cat <<- EOF > $HOME/.local/share/applications/my-emacs.desktop
		[Desktop Entry]
		Terminal=false
		Name=Emacs
		Exec=$DIR/$TOOL/$BIN/emacs %U
		Type=Application
		Icon=$DIR/$TOOL/latest/share/icons/hicolor/128x128/apps/emacs.png
		StartupWMClass=Emacs
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=doom                  # emacs doom mode
install_doom(){
	local url version tool
	git clone --depth 1 https://github.com/hlissner/doom-emacs $HOME/.emacs.d
	$HOME/.emacs.d/bin/doom install
	$HOME/.emacs.d/bin/doom sync

	FOUND=true
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && install_$TOOL # do not call run install_ to avoid mkdir - thus set FOUND manually to true

TOOL=shellcheck            # a shell script static analysis tool
install_shellcheck(){
	_cleanup::install_shellcheck(){
		rm -f $TOOL.tar.xz
	}

	local url version
	url='https://github.com/'$(curl -s https://github.com/koalaman/shellcheck/releases | grep -oE 'koalaman/\S+shellcheck-v[0-9\.]+\.linux\.x86_64\.tar\.xz' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/shellcheck-v([0-9\.]+)\..+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.xz
	tar -xf $TOOL.tar.xz && rm -f $TOOL.tar.xz
	mv shellcheck* $version
	ln -sfnr $version latest
	BIN=latest
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=mdless                # a ruby based terminal markdown viewer
install_mdless(){
	_cleanup::install_mdless(){
		rm -f $TOOL.tar.gz
	}

	local url version

	url='https://github.com/'$(curl -s https://github.com/ttscoff/mdless/releases | grep -oE 'ttscoff/mdless/\S+\/[0-9\.]+\.tar\.gz' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/([0-9\.]+)\..+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz
	tar -xzf $TOOL.tar.gz && rm -f $TOOL.tar.gz
	mv mdless* $version
	sed -i 's@require@$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)\nrequire@' $version/bin/mdless
	ln -sfnr $version latest
	BIN=latest/bin
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=freetube              # full blown youtube client without ads and tracking
install_freetube(){
	_cleanup::install_freetube(){
		rm -f $TOOL.AppImage
	}

	local url version
	url='https://github.com/'$(curl -s https://github.com/FreeTubeApp/FreeTube/releases | grep -oE 'FreeTubeApp/\S+FreeTube-[0-9\.]+\.AppImage' | sort -Vr | head -1)
	version=$(basename $url | sed -E 's/FreeTube-([0-9\.]+)\..+/\1/')
	wget -c -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.AppImage
	chmod 755 $TOOL.AppImage
	rm -rf $version
	./$TOOL.AppImage --appimage-extract && rm -f $TOOL.AppImage
	mv squashfs-root $version
	mkdir -p $version/bin
	ln -sfnr $version/AppRun $version/bin/freetube
	ln -sfnr $version latest
	BIN=latest/bin

	cat <<- EOF > $HOME/.local/share/applications/my-freetube.desktop
		[Desktop Entry]
		Terminal=false
		Name=FreeTube
		Exec=$DIR/$TOOL/latest/bin/freetube
		Type=Application
		Icon=$DIR/$TOOL/latest/usr/share/icons/hicolor/256x256/apps/freetube.png
		StartupWMClass=FreeTube
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

ERROR="${!OPT[*]} not found"
${FOUND:=false}
cat <<- EOF
	:INFO: success
	:INFO: to load tools read usage INFO section! execute '$(basename $0) -h'
EOF

exit 0
