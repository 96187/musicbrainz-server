cd /home/nikki/translations/po &&
/usr/local/bin/tx pull &&
perl -pi -e 's/(Last-Translator: .*<)[^<>]+(>\\n")$/$1email address hidden$2/' *.po &&
perl -pi -e 's/^(#.*<)[^<>]+(>, [0-9]+.*)$/$1email address hidden$2/' *.po &&
git commit -q -a -m 'Update translations from Transifex' &&
git push -q github translations
