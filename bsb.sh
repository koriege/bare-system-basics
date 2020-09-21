#! /usr/bin/env bash
# (c) Konstantin Riege
trap '
	sleep 1
	pids=($(pstree -p $$ | grep -Eo "\([0-9]+\)" | grep -Eo "[0-9]+" | tail -n +2))
	{ kill -KILL "${pids[@]}" && wait "${pids[@]}"; } &> /dev/null
	printf "\r"
' EXIT
trap 'die "killed"' INT TERM

die(){
	echo ":ERROR: $*" >&2
	exit 1
}

############### GLOBAL VARS ###############

DIR=$HOME/programs
SOURCE=$DIR/SOURCE.me
THREADS=$(cat /proc/cpuinfo | grep -cF processor)
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
		0.4.0

		SYNOPSIS
		$(basename $0) -i [tool]

		OPTIONS
		-h | --help           # prints this message
		-d | --dir [path]     # installation path - default: $DIR
		-t | --threads [num]  # threads to use for comilation - default: $THREADS
		-i | --install [tool] # tool(s) to install/update (comma seperated, see below) - default: "all"
		                      # except cronjob, conda-env, r-libs and perl-libs

		TOOLS
		$tools

		INFO
		1) how to use conda tools and non-conda libraries
		- to load conda itself, execute 'source $DIR/conda/latest/bin/activate'
		- to load conda tools execute 'conda env list', and 'conda activate [env]'
		- to load non-conda installed perl packages execute 'export PERL5LIB=$DIR/perl-libs/<version>/lib/perl5'
		- to load non-conda installed r packages execute 'export R_LIBS=$DIR/r-libs/<version>'

		2) to define a tool as default application
		- adapt ~/.config/mimeapps.list
		- adapt ~/.local/share/applications/mimeapps.list

		3) in case of onlyoffice scaling issues
		- adjust QT settings in ~/.local/share/applications/my-onlyoffice.desktop

		4) to group multiple windows in gnome application dock
		- define StartupWMClass in .desktop file
		- assign value by executing 'xprop WM_CLASS' + click on window

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
		-i | --i | -install | --install) arg=true; OPT=(); mapfile -d ',' -t <<< $2 ; for t in "${MAPFILE[@]}"; do t=$(printf "%s" $t); OPT[$t]=1; done;;
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

run(){
	FOUND=true
	unset BIN
	{	mkdir -p $DIR/$TOOL && \
		cd $DIR/$TOOL && \
		$1
	} || die $TOOL
	# adapt source
	touch $SOURCE
	[[ $BIN ]] && {
		sed -i "/PATH=/d" $SOURCE
		sed -i "\@$DIR/$TOOL@d" $SOURCE #\@ necessary for path matches - s@/dir/path/@replacement@ is okay , @/dir/path/@d not
		echo 'VAR=$VAR:'"$DIR/$TOOL/$BIN" >> $SOURCE
		echo 'PATH=$VAR:$PATH' >> $SOURCE
	}

	return 0
}

javawrapper() {
	local java=java
	[[ $3 ]] && java="$3"
	cat <<- EOF > "$1" || return 1
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
	chmod 755 "$1" || return 1

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

TOOL=cronjob               # setup a cron job file to update all softare once a month
install_cronjob(){
	local src
	# <minute> <hour> <day of month> <month> <day of week> <command>
	{	src=$(dirname $(readlink -e $0)) && \
		echo "0 0 1 * * $(readlink -e $0) -i all -d $DIR -t $THREADS" > $src/cron.job
	} || return 1

	FOUND=true
	return 0
}
[[ ${OPT[$TOOL]} ]] && install_$TOOL

TOOL=google-chrome         # google chrome webbrowser
install_google-chrome(){
	local url version
	{	url='https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb && ar p $TOOL.deb data.tar.xz | tar xJ && rm $TOOL.deb && \
		version=$(opt/google/chrome/google-chrome --version | awk '{print $NF}') && \
		rm -rf $version && mv opt $version && rm -rf usr && rm -rf etc && \
		ln -sfnr $version latest && \
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
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=vivaldi               # sophisticated chrome based webbrowser - highly recommended :)
install_vivaldi(){
	local url version
	{	url=$(curl -s https://vivaldi.com/download/archive/?platform=linux | grep -Eo 'http[^"]+vivaldi-stable_[^"]+amd64\.deb' | sort -Vr | head -1) && \
		version=$(basename $url | sed -E 's/vivaldi-stable_([0-9\.]+).+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb && ar p $TOOL.deb data.tar.xz | tar xJ && rm $TOOL.deb && \
		rm -rf $version  && mv opt $version && rm -rf usr && rm -rf etc && \
		ln -sfnr $version latest && \
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
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=opera                 # chrome based webbrowser with vpn
install_opera(){
	local url version
	{	url='https://get.geo.opera.com/pub/opera/desktop/' && \
		version=$(curl -s $url | grep -oE 'href="[0-9]+[0-9\.]+' | cut -d '"' -f 2 | sort -Vr | head -1) && \
        url="$url$version/linux/opera-stable_${version}_amd64.deb"
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb && ar p $TOOL.deb data.tar.xz | tar xJ && rm $TOOL.deb && \
		rm -rf $version && mv usr $version && \
		ln -sfnr $version latest && \
		BIN=latest/bin
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-opera.desktop || return 1
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
	local url version
	{	url='https://ftp.mozilla.org/pub/firefox/releases/' && \
		version=$(curl -s $url | grep -oE 'releases/[0-9\.]+' | cut -d '/' -f 2 | sort -Vr | head -1) && \
		url="$url$version/linux-x86_64/en-US/firefox-$version.tar.bz2" && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.bz2 && tar -xjf $TOOL.tar.bz2 && rm $TOOL.tar.bz2 && \
		rm -rf $version && mv firefox* $version && \
		ln -sfnr $version latest && \
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
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=thunderbird           # updates itself. thunderbird email tool - best until vivaldi m3 is released
install_thunderbird(){
	local url version
	{	url='https://ftp.mozilla.org/pub/thunderbird/releases/' && \
		version=$(curl -s $url | grep -oE 'releases/[0-9\.]+' | cut -d '/' -f 2 | sort -Vr | head -1) && \
		url="$url$version/linux-x86_64/en-US/thunderbird-$version.tar.bz2" && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.bz2 && tar -xjf $TOOL.tar.bz2 && rm $TOOL.tar.bz2 && \
		rm -rf $version && mv thunderbird* $version && \
		ln -sfnr $version latest && \
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
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=keeweb                # keepass db compatible password manager with cloud sync support
install_keeweb(){
	local url version
	{	url='https://github.com/'$(curl -s https://github.com/keeweb/keeweb/releases | grep -oE 'keeweb/\S+KeeWeb-[0-9\.]+\.linux.x64.zip' | sort -Vr | head -1) && \
		version=$(basename $url | sed -E 's/KeeWeb-([0-9\.]+)\..+/\1/') && \
        rm -rf $version && mkdir $version && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.zip && unzip -q $TOOL.zip -d $version && rm $TOOL.zip && \
		ln -sfnr $version latest && \
		BIN=latest
	} || return 1
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
	local url version
	# under forced login: url="https://download.oracle.com/otn-pub/java/jdk/13.0.2+8/d4173c853231432d94f001e99d882ca7/jdk-13.0.2_linux-x64_bin.tar.gz"
	{	url="https://download.oracle.com/otn-pub/java/jdk/14.0.2+12/205943a0976c4ed48cb16f1043c5c647/jdk-14.0.2_linux-x64_bin.tar.gz" && \
		version=$(basename $url | sed -E 's/jdk-([0-9\.]+).+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" $url -O $TOOL.tar.gz && \
		tar -xzf $TOOL.tar.gz && rm $TOOL.tar.gz && \
		rm -rf $version && mv jdk* $version && \
		ln -sfnr $version latest && \
		BIN=latest/bin && \
		return 0
	} || return 1
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=pdf-editor4           # master pdf viewer and editor v4 (latest without watermark)
install_pdf-editor4(){
	local url version
	#url=$(curl -s https://code-industry.net/free-pdf-editor/ | grep -Eo 'http[^"]+qt5.amd64.tar.gz')
	{	url='http://code-industry.net/public/master-pdf-editor-4.3.89_qt5.amd64.tar.gz' && \
		version=$(basename $url | sed -E 's/master-pdf-editor-([0-9\.]+).+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz && tar -xzf $TOOL.tar.gz && rm $TOOL.tar.gz && \
		rm -rf $version && mv master-pdf-editor* $version && \
		ln -sfnr $version latest && \
		BIN=latest
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-masterpdfeditor4.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Masterpdfeditor4
		Exec=$DIR/$TOOL/$BIN/masterpdfeditor4
		Type=Application
		Icon=$DIR/$TOOL/$BIN/masterpdfeditor4.png
		StartupWMClass=Masterpdfeditor4
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=pdf-editor5           # master pdf viewer and editor v5
install_pdf-editor5(){
	local url version
	{	url=$(curl -s https://code-industry.net/free-pdf-editor/ | grep -oE 'http\S+qt5\S+\.tar\.gz') && \
		version=$(basename $url | sed -E 's/master-pdf-editor-([0-9\.]+).+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz && tar -xzf $TOOL.tar.gz && rm $TOOL.tar.gz && \
		rm -rf $version && mv master-pdf-editor* $version && \
		ln -sfnr $version latest && \
		BIN=latest
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-masterpdfeditor5.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Masterpdfeditor5
		Exec=$DIR/$TOOL/$BIN/masterpdfeditor5
		Type=Application
		Icon=$DIR/$TOOL/$BIN/masterpdfeditor5.png
		StartupWMClass=Masterpdfeditor5
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=sublime               # very powerful text editor and integrated developer environment for all languages
install_sublime(){
	local url version
	{	url=$(curl -s  https://www.sublimetext.com/3 | grep -Eo 'http\S+x64\.tar\.bz2' | sort -Vr | head -1) && \
		version=$(basename $url | sed -E 's/.+build_([0-9\.]+).+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.bz2 && tar -xjf $TOOL.tar.bz2 && rm $TOOL.tar.bz2 && \
		rm -rf $version && mv sublime* $version && \
		mkdir -p $version/bin && \
		ln -sfnr $version/sublime_text $version/bin/subl && \
		ln -sfnr $version/sublime_text $version/bin/ && \
		ln -sfnr $version latest && \
		BIN=latest/bin
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
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=sublime-merge         # very powerful git client
install_sublime-merge(){
	local url version
	{	url=$(curl -s https://www.sublimemerge.com/download | grep -oE 'http\S+x64.tar.xz' | sort -Vr | head -1) && \
		version=$(basename $url | sed -E 's/.+build_([0-9\.]+).+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.xz && tar -xf $TOOL.tar.xz && rm $TOOL.tar.xz && \
		rm -rf $version && mv sublime* $version && \
		mkdir -p $version/bin && \
		ln -sfnr $version/sublime_merge $version/bin/sublmerge && \
		ln -sfnr $version/sublime_merge $version/bin/ && \
		ln -sfnr $version latest && \
		BIN=latest/bin
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
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=adb                   # minimal installation of android debugging bridge and sideload
install_adb(){
	local url version
	{	url='https://dl.google.com/android/repository/platform-tools-latest-linux.zip' && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.zip && unzip -q $TOOL.zip && rm $TOOL.zip && \
		version=$(platform-tools*/adb version | grep -F version | cut -d ' ' -f 5) && \
		rm -rf $version && \
		mv platform-tools* $version && \
		ln -sfnr $version latest && \
		BIN=latest && \
		return 0
	} || return 1
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=conda                 # root less package control software
install_conda(){
	unset BIN
	local url version
	# conda >= 4.7 may leads to failed with initial frozen solve issue
	{	url='https://repo.anaconda.com/miniconda/Miniconda3-4.6.14-Linux-x86_64.sh' && \
		url='https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh' && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O miniconda.sh && \
		version=$(bash miniconda.sh -h | grep -F Installs | cut -d ' ' -f 3) && \
		rm -rf $version && \
		bash miniconda.sh -b -f -p $version && \
		ln -sfnr $version latest && \
		BIN=latest/condabin && \
		return 0
	} || return 1
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=conda-env             # setup dev env via conda. compilers, perl + packages ,r-base , datamash, ghostscript, pigz
install_conda-env(){
	[[ -n $CONDA_PREFIX ]] || die 'please activate conda first'
	local name="py3_dev_$(date +%F)"
	conda env remove -y -n $name || die 'please switch to base environment'
	conda config --set changeps1 False

	# for py2 env: perl-libs XML::Parser requires expat, Bio::Perl requires perl-dbi perl-db-file
	# -> in py3 env self compiling perl modules is terrifying

	# r-libs ggpubr requires nlopt
	{	conda create -y -n $name python=3 && \
		conda install -n $name -y --override-channels -c iuc -c conda-forge -c bioconda -c main -c defaults -c r -c anaconda \
			gcc_linux-64 gxx_linux-64 gfortran_linux-64 \
			glib pkg-config make automake cmake \
			bzip2 pigz pbzip2 \
			curl ghostscript dos2unix datamash \
			htslib expat nlopt \
			perl-threaded perl-app-cpanminus perl-dbi perl-db-file perl-xml-parser perl-bioperl perl-bio-eutilities \
			r-base  && \
			# rstudio
		conda clean -y -a
		# rstudio is old and in r channel and depends on old r channel r-base whereas r-base in actively maintained in conda-forge
		# furthermore, when using conda rstudio there will be clashes of r channel r-base version and other channel libraries r built versions
	} || return 1

	FOUND=true
	return 0
}
[[ ${OPT[$TOOL]} ]] && install_$TOOL # do not call run install_ to avoid mkdir - thus set FOUND manually to true

TOOL=python-libs           # conda/non-conda: numpy scipy pysam cython matplotlib
install_python-libs(){
	mkdir -p src
	if [[ $CONDA_PREFIX && $(conda env list | awk '$2=="*"{print $1}') != "base" ]]; then
		{	pip download -d $PWD/src numpy scipy pysam cython matplotlib && \
			pip install --force-reinstall --find-links $PWD/src numpy scipy pysam cython matplotlib && \
			return 0
		} || return 1
	else
		local x url
		read -r -p ':WARNING: current environment may not fulfill all prerequisites and dependencies. please try with an activated conda environment or continue? (y|n): ' x
		[[ $x == "n" ]] && return 0
		version=$(python --version | awk '{print $NF}')
		mkdir -p $version
		{	pip download -d $PWD/src numpy scipy pysam cython matplotlib && \
			pip install --force-reinstall --prefix $PWD/$version --find-links $PWD/src numpy scipy pysam cython matplotlib && \
			return 0
		} || return 1
	fi
}
[[ ${OPT[$TOOL]} ]] && run install_$TOOL # do not call run install_ to avoid mkdir - thus set FOUND manually to true

TOOL=r-libs                # conda/non-conda: dplyr tidyverse ggpubr ggplot2 gplots RColorBrewer svglite pheatmap data.table BiocParallel genefilter DESeq2 TCGAutils TCGAbiolinks
install_r-libs(){
	mkdir -p src
	if [[ $CONDA_PREFIX && $(conda env list | awk '$2=="*"{print $1}') != "base" ]]; then
		{	Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages(c('devtools','codetools','dplyr','tidyverse','ggpubr','ggplot2','gplots','RColorBrewer','svglite','pheatmap','data.table'), repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src')" && \
			Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); devtools::install_github(c('andymckenzie/DGCA'), upgrade='never', force=T, Ncpus=$THREADS, clean=T, destdir='$PWD/src')" && \
			if [[ $(conda list -n $name -f r-base | tail -1 | awk '$2<3.5{print "legacy"}') ]]; then
				Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); source('https://bioconductor.org/biocLite.R'); BiocInstaller::biocLite(c('BiocParallel','genefilter','DESeq2','TCGAutils','TCGAbiolinks'), ask=F, Ncpus=$THREADS, clean=T, destdir='$PWD/src')" && \
				return 0
			else
				Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages('BiocManager', repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src')" && \
				Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); BiocManager::install(c('BiocParallel','genefilter','DESeq2','TCGAutils','TCGAbiolinks'), ask=F, Ncpus=$THREADS, clean=T, destdir='$PWD/src')" && \
				return 0
			fi
		} || return 1
	else
		local x version
		read -r -p ':WARNING: current environment may not fulfill all prerequisites and dependencies. please try with an activated conda environment or continue? (y|n): ' x
		[[ $x == "n" ]] && return 0
		version=$(Rscript --version 2>&1 | awk '{print $(NF-1)}')
		mkdir -p $version
		{	Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages(c('devtools','codetools','dplyr','tidyverse','ggpubr','ggplot2','gplots','RColorBrewer','svglite','pheatmap','data.table'), repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')" && \
			Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); devtools::install_github(c('andymckenzie/DGCA'), Ncpus=$THREADS, upgrade='never', force=T, Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')" && \
			if [[ $(conda list -n $name -f r-base | tail -1 | awk '$2<3.5{print "legacy"}') ]]; then
				Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); source('https://bioconductor.org/biocLite.R'); BiocInstaller::biocLite(c('BiocParallel','genefilter','DESeq2','TCGAutils','TCGAbiolinks'), ask=F, Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')" && \
				return 0
			else
				Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); install.packages('BiocManager', repos='http://cloud.r-project.org', Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')" && \
				Rscript -e "options(unzip='$(command -v unzip)'); Sys.setenv(TAR='$(command -v tar)'); BiocManager::install(c('BiocParallel','genefilter','DESeq2','TCGAutils','TCGAbiolinks'), ask=F, Ncpus=$THREADS, clean=T, destdir='$PWD/src', lib='$PWD/$version')" &&
				return 0
			fi
		} || return 1
	fi
}
[[ ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=perl-libs             # conda/non-conda: Try::Tiny List::MoreUtils DB_File Bio::Perl Bio::DB::EUtilities Tree::Simple XML::Simple
install_perl-libs(){
	mkdir -p src
	local x
	if [[ $CONDA_PREFIX && $(conda env list | awk '$2=="*"{print $1}') != "base" ]]; then
		[[ $($CONDA_PYTHON_EXE --version | awk '{printf "%d",$NF}') -eq 3 ]] && {
			read -r -p ':WARNING: current conda environment may not fulfill all prerequisites and dependencies. (y|n): ' x
			[[ $x == "n" ]] && return 0
		}
		# in worst case make use of
		# CFLAGS="-I$CONDA_PREFIX/include"
		# LDFLAGS="-L$CONDA_PREFIX/lib"
		# CPATH="$CONDA_PREFIX/include"
		# LIBRARY_PATH="$CONDA_PREFIX/lib"
		# LD_LIBRARY_PATH="$CONDA_PREFIX/lib"
		{	env EXPATINCPATH="$CONDA_PREFIX/include" EXPATLIBPATH="$CONDA_PREFIX/lib" cpanm -l /dev/null --force --scandeps --save-dists $PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple && \
			env EXPATINCPATH="$CONDA_PREFIX/include" EXPATLIBPATH="$CONDA_PREFIX/lib" cpanm --reinstall --mirror file://$PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple && \
			return 0
		} || return 1
	else
		local url
		read -r -p ':WARNING: current environment may not fulfill all prerequisites and dependencies. please try with an activated conda environment or continue? (y|n): ' x
		[[ $x == "n" ]] && return 0
		version=$(perl --version | head -2 | tail -1 | sed -E 's/.+\(v(.+)\).+/\1/')
		mkdir -p $version
		{	url='cpanmin.us' && \
			wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O cpanm && \
			chmod 755 cpanm && \
			./cpanm -l /dev/null --force --scandeps --save-dists $PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple && \
			./cpanm -l $PWD/$version --reinstall --mirror file://$PWD/src Bio::Perl Bio::DB::EUtilities Tree::Simple Try::Tiny List::MoreUtils XML::Simple && \
			return 0
		} || return 1
	fi
}
[[ ${OPT[$TOOL]} ]] && run install_$TOOL # do not call run install_ to avoid mkdir - thus set FOUND manually to true

TOOL=htop                  # graphical task manager
install_htop(){
	local url version
	{	url='http://hisham.hm/htop/releases/' && \
		version=$(curl -s $url | grep -oE 'href="[0-9\.]+' | cut -d '"' -f 2 | sort -Vr | head -1) && \
		url="$url$version/htop-$version.tar.gz" && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz && tar -xzf $TOOL.tar.gz && rm $TOOL.tar.gz && \
		rm -rf $version && mkdir -p $version && \
		cd htop* && \
		./configure --prefix=$DIR/$TOOL/$version && \
		make -j $THREADS && \
		make install && \
		make clean && \
		cd .. && \
		rm -rf htop* && \
		ln -sfnr $version latest && \
		BIN=latest/bin && \
		return 0
	} || return 1
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=jabref                # references/citations manager
install_jabref(){
	local url version
	{	url='https://github.com/'$(curl -s https://github.com/JabRef/jabref/releases | grep -oE 'JabRef/\S+JabRef-[0-9\.]+-portable_linux\.tar\.gz' | sort -Vr | head -1) && \
		version=$(basename $url | sed -E 's/JabRef-([0-9\.]+).+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz && tar -xzf $TOOL.tar.gz && rm $TOOL.tar.gz && \
		rm -rf $version && mv JabRef $version && \
		ln -sfnr $version latest && \
		BIN=latest/bin && \
		return 0
	} || return 1
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=igv                   # interactive genome viewer (needs java >=11)
install_igv(){
	local url version
	{	url=$(curl -s https://software.broadinstitute.org/software/igv/download | grep -Eo 'http\S+IGV_[0-9\.]+\.zip' | sort -Vr | head -1) && \
		version=$(basename $url | sed -E 's/IGV_([0-9\.]+)\..+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.zip && unzip -q $TOOL.zip && rm $TOOL.zip && \
		rm -rf $version && mv IGV* $version && \
		mem=$(grep -F -i memavailable /proc/meminfo | awk '{printf("%d",$2*0.8/1024/1024)}') && \
		sed -i -r "s/-Xmx\S+/-Xmx${mem}g/" $version/igv.sh && \
	    sed -i 's/readlink[^$]/readlink -f /' $version/igv.sh && \
		mkdir -p $version/bin && \
		ln -sfnr $version/igv.sh $version/bin/igv && \
		ln -sfnr $version latest && \
		BIN=latest/bin && \
		return 0
	} || return 1
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=tilix                 # best terminal emulator
install_tilix(){
	local url version
	{	url='https://github.com/'$(curl -s https://github.com/gnunn1/tilix/releases/ | grep -oE 'gnunn1\S+tilix.zip' | sort -Vr | head -1) && \
		version=$(basename $(dirname $url)) && \
		rm -rf $version && mkdir -p $version && \
		cd $version  && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.zip && unzip -q $TOOL.zip && rm $TOOL.zip && \
		mv usr/* . && rm -rf usr && \
		glib-compile-schemas share/glib-*/schemas/ && \
		touch bin/tilix.sh && \
		chmod 755 bin/* && \
		inkscape -D -w 256 -h 256 -e share/icons/hicolor/icon.png share/icons/hicolor/scalable/apps/com.gexperts.Tilix.svg && \
		cd .. && \
		ln -sfnr $version latest && \
		BIN=latest/bin
	} || return 1
	cat <<- EOF > $DIR/$TOOL/$version/bin/tilix.sh || return 1
		#!/usr/bin/env bash
		export XDG_DATA_DIRS="\${XDG_DATA_DIRS:+\$XDG_DATA_DIRS:}$DIR/$TOOL/$version/share"
		export GSETTINGS_SCHEMA_DIR="\${GSETTINGS_SCHEMA_DIR:+\$GSETTINGS_SCHEMA_DIR:}$DIR/$TOOL/$version/share/glib-2.0/schemas"
		source /etc/profile.d/vte.sh
		$DIR/$TOOL/$version/bin/tilix
	EOF
	cat <<- EOF > $HOME/.local/share/applications/my-tilix.desktop || return 1
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

TOOL=meld                  # compare files
install_meld(){
	local url version
	{	url=$(curl -s http://meldmerge.org/ | grep -oE 'http\S+meld-[0-9\.]+\.tar\.xz' | sort -Vr | head -1) && \
		version=$(basename $url | sed -E 's/meld-([0-9\.]+)\..+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.xz && tar -xf $TOOL.tar.xz && rm $TOOL.tar.xz && \
		rm -rf $version && mv meld* $version && \
		ln -sfnr $version latest && \
		BIN=latest/bin && \
		return 0
	} || return 1
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=spotify               # spotify - may need sudo ln -sf /usr/lib64/libcurl.so.4 /usr/lib64/libcurl-gnutls.so.4
install_spotify(){
	local url version
	{	url='https://repository-origin.spotify.com/pool/non-free/s/spotify-client/' && \
		url="$url"$(curl -s $url | grep -oE 'spotify-client_[^"]+_amd64.deb' | sort -Vr | head -1) && \
		version=$(basename $url | sed -E 's/spotify-client_([0-9\.]+)\..+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb && ar p $TOOL.deb data.tar.gz | tar xz && rm $TOOL.deb && \
		rm -rf $version  && mv usr/share/spotify $version && rm -rf usr && rm -rf etc && \
		mkdir -p $version/bin && \
		ln -sfnr $version/spotify $version/bin/ && \
		ln -sfnr $version latest && \
		BIN=latest/bin
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-spotify.desktop || return 1
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
	local url
	{	url='https://go.skype.com/skypeforlinux-64.deb' && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb && ar p $TOOL.deb data.tar.xz | tar xJ && rm $TOOL.deb && \
		rm -rf opt latest && \
		mv usr latest && \
		ln -sfnr latest/bin/skypeforlinux latest/bin/skype && \
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
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=onlyoffice            # nice ms office clone
install_onlyoffice(){
	local url
	{	url='http://download.onlyoffice.com/install/desktop/editors/linux/DesktopEditors-x86_64.AppImage' && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.AppImage && \
		chmod 755 $TOOL.AppImage && \
		version=$(./$TOOL.AppImage --version 2>&1 | tail -n 1 | rev | cut -d ' ' -f 1 | rev) && \
		./$TOOL.AppImage --appimage-extract && \
		rm -f $TOOL.AppImage && \
		rm -rf $version && mv squashfs-root $version && \
		mkdir -p $version/bin && \
		ln -sfnr $version/AppRun $version/bin/onlyoffice && \
		ln -sfnr $version latest && \
		BIN=latest/bin
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-onlyoffice.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=Onlyoffice
		Exec=env QT_SCREEN_SCALE_FACTORS=1 QT_SCALE_FACTOR=0.5 $DIR/$TOOL/$BIN/onlyoffice --force-scale=1
		Type=Application
		Icon=$DIR/$TOOL/latest/asc-de.png
		StartupWMClass=DesktopEditors
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=wpsoffice             # best ms office clone available - please check version/url update manually at http://linux.wps.com
install_wpsoffice(){
	local url
	{	url='http://wdl1.pcfg.cache.wpscdn.com/wpsdl/wpsoffice/download/linux/9615/wps-office_11.1.0.9615.XA_amd64.deb' && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.deb && ar p $TOOL.deb data.tar.xz | tar xJ && rm $TOOL.deb && \
		version=$(basename $url | sed -E 's/wps-office_([0-9\.]+)\..+/\1/') && \
		mv opt/kingsoft/wps-office/office6 $version && \
		mv usr/share/icons/hicolor/512x512/mimetypes $version/icons && \
		rm -rf opt usr etc && \
		mkdir -p $version/bin && \
		ln -sfnr $version/wps $version/bin/wps-write && \
		ln -sfnr $version/wpp $version/bin/wps-present && \
		ln -sfnr $version/wpspdf $version/bin/wps-pdf && \
		ln -sfnr $version/et $version/bin/wps-calc && \
		mkdir -p ~/.local/share/fonts && \
		mv usr/share/fonts/wps-office/* ~/.local/share/fonts && \
		ln -sfnr $version latest && \
		BIN=latest/bin
	} || return 1
	cat <<- EOF > $HOME/.local/share/applications/my-wpsoffice-write.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=WPSoffice-Write
		Exec=$DIR/$TOOL/$BIN/wps-write
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/wps-office2019-wpsmain.png
		StartupWMClass=Wps-write
	EOF
	cat <<- EOF > $HOME/.local/share/applications/my-wpsoffice-present.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=WPSoffice-Present
		Exec=$DIR/$TOOL/$BIN/wps-present
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/wps-office2019-wppmain.png
		StartupWMClass=Wps-present
	EOF
	cat <<- EOF > $HOME/.local/share/applications/my-wpsoffice-calc.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=WPSoffice-Calc
		Exec=$DIR/$TOOL/$BIN/wps-calc
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/wps-office2019-etmain.png
		StartupWMClass=Wps-calc
	EOF
		cat <<- EOF > $HOME/.local/share/applications/my-wpsoffice-pdf.desktop || return 1
		[Desktop Entry]
		Terminal=false
		Name=WPSoffice-PDF
		Exec=$DIR/$TOOL/$BIN/wps-pdf
		Type=Application
		Icon=$DIR/$TOOL/latest/icons/wps-office2019-pdfmain.png
		StartupWMClass=Wps-pdf
	EOF
	return 0
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

TOOL=emacs                 # emacs rulez in non-evil doom mode or use provided config as ~/.emacs
install_emacs(){
	local url version tool
	{	url='http://ftp.gnu.org/gnu/emacs/' && \
		url="$url"$(curl -s $url | grep -oE 'emacs-[0-9\.]+\.tar\.gz' | sort -Vr | head -1) && \
		version=$(basename $url | sed -E 's/emacs-([0-9\.]+)\..+/\1/') && \
		wget -q --show-progress --progress=bar:force --waitretry 1 --tries 5 --retry-connrefused -N $url -O $TOOL.tar.gz && tar -xzf $TOOL.tar.gz && rm $TOOL.tar.gz && \
		rm -rf $version && mkdir -p $version && \
		cd emacs* && \
		./configure --prefix=$DIR/$TOOL/$version --with-x-toolkit=no --with-xpm=ifavailable --with-gif=ifavailable && \
		make -j $THREADS && \
		make install && \
		make clean && \
		cd .. && \
		rm -rf emacs* && \
		ln -sfnr $version latest && \
		BIN=latest/bin && \
		return 0
	} || return 1
}
[[ ${OPT[all]} || ${OPT[$TOOL]} ]] && run install_$TOOL

${FOUND:=false} && {
	cat <<- EOF
		:INFO: success
		:INFO: to load tools read usage INFO section! execute '$(basename $0) -h'
	EOF
} || {
	die "${!OPT[@]}" " not found"
}
