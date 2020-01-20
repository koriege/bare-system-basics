# baresystembasics

no-root software installer and updater for non production ready linux environments

## usage
```
setup.sh -h
setup.sh -i [tool|all]
```

## integrated tools
```
- google-chrome         # google chrome webbrowser
- slimjet               # lightweight chrome based webbrowser with built in adblock
- vivaldi               # sophisticated chrome based webbrowser - highly recommended :)
- opera                 # chrome based webbrowser with vpn
- cpanm                 # !!! comes with conda-tools installation. cpanminus to install perl modules
- java                  # oracle java 11 runtime and development kit
- igv                   # !!! needs java 11. interactive genome viewer
- master-pdf-editor     # nice pdf viewer and editor
- sublime               # very powerful text editor and integrated developer environment for all languages
- sublime-merge         # very powerful git client
- thunderbird           # updates itself. thunderbird email tool
- firefox               # updates via interface possible. firefox webbrowser
- skype                 # !!! may fail to be installed on some systems
- adb                   # minimal installation of android debugging bridge and sideload
- conda                 # root less package control software
- conda-tools           # install tools via conda. perl, r, rstudio, datamash, gcc
- perl-modules          # !!! you need to install cpanm or install and activate conda first. Try::Tiny List::MoreUtils DB_File Bio::Perl Bio::DB::EUtilities Tree::Simple XML::Simple
- htop                  # graphical task manager
- jabref                # references/citations manager
- tilix                 # best terminal emulator
- meld                  # compare files
- spotify               # spotify - may need sudo ln -sf /usr/lib64/libcurl.so.4 /usr/lib64/libcurl-gnutls.so.4
```
