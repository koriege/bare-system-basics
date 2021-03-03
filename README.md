# bare-system-basics

Non-root software installer and updater for non production ready `*NIX` environments.


The `bsb.sh` setup routine brings a selection of software locally to your linux computer. Within the scope of life-science/bioinformatics, a Python3 conda environment, R and Perl libraries can be compiled as well. Optionally, find enclosed my fallback emacs configuration (see also <https://github.com/hlissner/doom-emacs>).

# license

The whole project is licensed under the GPL v3 (see LICENSE file for details). <br>
**except** the the third-party tools set-upped during installation. Please refer to the corresponding licenses

Copyleft (C) 2020, Konstantin Riege

# download

Either fetch the latest release archive or utilize `git` as shown below
<br>
This will download you a copy which includes the latest developments

```bash
git clone https://github.com/Hoffmann-Lab/bare-system-basics
```

To check out the latest release (irregularly compiled) do

```bash
cd bare-system-basics
git checkout $(git describe --tags)
```

# usage

```
bsb.sh -h
bsb.sh -i [tool|all] -d <installpath>
source <installpath>/SOURCE.me
```

# supported tools

| tool | description |
| :--- | :---        |
| cronjob               | setup a cron job file to update all softare once a month |
| google-chrome         | google chrome webbrowser |
| vivaldi               | sophisticated chrome based webbrowser - highly recommended :) |
| opera                 | chrome based webbrowser with vpn |
| firefox               | updates via interface possible. firefox webbrowser |
| thunderbird           | updates itself. thunderbird email tool - best until vivaldi m3 is released |
| keeweb                | keepass db compatible password manager with cloud sync support |
| java                  | oracle java runtime and development kit |
| pdf-editor4           | master pdf viewer and editor v4 (latest without watermark) |
| pdf-editor5           | master pdf viewer and editor v5 |
| sublime               | very powerful text editor and integrated developer environment for all languages |
| sublime-merge         | very powerful git client |
| adb                   | minimal installation of android debugging bridge and sideload |
| conda                 | root less package control software |
| conda-env             | setup dev env via conda. perl + packages ,r , datamash, gcc, pigz, htslib |
| perl-libs             | conda/non-conda: `numpy scipy pysam cython matplotlib` |
| r-libs                | conda/non-conda: `dplyr tidyverse ggpubr ggplot2 gplots RColorBrewer svglite pheatmap data.table BiocParallel genefilter DESeq2 DEXSeq clusterProfiler TCGAutils TCGAbiolinks WGCNA DGCA` |
| perl-libs             | conda/non-conda: `Try::Tiny List::MoreUtils DB_File Bio::Perl Bio::DB::EUtilities Tree::Simple XML::Simple` |
| htop                  | graphical task manager |
| jabref                | references/citations manager |
| igv                   | interactive genome viewer (needs java >=11) |
| tilix                 | best terminal emulator |
| meld                  | compare files |
| spotify               | spotify - may need `sudo ln -sf /usr/lib64/libcurl.so.4 /usr/lib64/libcurl-gnutls.so.4` |
| skype                 | !!! may fail to be installed on some systems |
| onlyoffice            | nice ms office clone |
| wpsoffice             | best ms office clone available - please check version/url update manually at http://linux.wps.com |
| emacs                 | emacs rulez in non-evil doom mode or use provided config as ~/.emacs |
| doom                  | emacs doom mode |
| shellcheck            | a shell script static analysis tool |
| mdless                | a ruby based terminal markdown viewer |
| freetube              | full blown youtube client without ads and tracking |

# info and trouble shooting

## how to use conda tools and non-conda libraries

- to load conda itself, execute `source <installpath>/conda/latest/bin/activate`
- to list and load a conda environment execute `conda info -e` and `conda activate [env]`
- to load non-conda installed perl packages execute `export PERL5LIB=<installpath>/perl-libs/<version>/lib/perl5`
- to load non-conda installed r packages execute `export R_LIBS=<installpath>/r-libs/<version>`
- to load non-conda installed python packages execute `export PYTHONPATH=<installpath>/python-libs/<version>`

## how to define a tool as default application
- adapt `~/.config/mimeapps.list`
- adapt `~/.local/share/applications/mimeapps.list`

## what to do in case of onlyoffice scaling issues
- adjust QT settings in `~/.local/share/applications/my-onlyoffice.desktop`

## how to group multiple windows in gnome application dock
- define or update StartupWMClass in `.desktop` file
- assign on of the values shown by executing `xprop WM_CLASS` + mouse-click on window
