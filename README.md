# bare-system-basics
---

Non-root software installer and updater for non production ready linux environments.
This setup routine brings a selection of software locally to your linux computer.

# License
---

The whole project is licensed under the GPL v3 (see LICENSE file for details). <br>
**except** the the third-party tools set-upped during installation. Please refer to the corresponding licenses

Copyleft (C) 2020, Konstantin Riege

# usage
---

```
setup.sh -h
setup.sh -i [tool|all] -d <installpath>
source <installpath>/SOURCE.me
```

# supported tools
---

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
| r-libs                | conda/non-conda: `dplyr tidyverse ggpubr ggplot2 gplots RColorBrewer svglite pheatmap data.table BiocParallel genefilter DESeq2`TCGAutils TCGAbiolinks |
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

# info and trouble shooting
---

## how to use conda tools and non-conda libraries

- to load conda itself, execute `source <installpath>/conda/latest/bin/activate`
- to load conda tools execute `conda env list', and 'conda activate [env]`
- to load non-conda installed perl packages execute `export PERL5LIB=<installpath>/perl-libs/<version>/lib/perl5`
- to load non-conda installed r packages execute `export R_LIBS=<installpath>/r-libs/<version>`

## how to define a tool as default application
- adapt `~/.config/mimeapps.list`
- adapt `~/.local/share/applications/mimeapps.list`

## what to do in case of onlyoffice scaling issues
- adjust QT settings in `~/.local/share/applications/my-onlyoffice.desktop`

## how to group multiple windows in gnome application dock
- define StartupWMClass in `.desktop` file
- assign value by executing `xprop WM_CLASS` and click on window
