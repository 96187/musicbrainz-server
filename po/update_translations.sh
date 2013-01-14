cd /home/nikki/translations/po &&
/usr/local/bin/tx pull &&
perl -pi -e 's/(Last-Translator: .*<)[^<>]+(>\\n")$/$1email address hidden$2/' *.po &&
perl -pi -e 's/^(#.*<)[^<>]+(>, [0-9]+.*)$/$1email address hidden$2/' *.po &&
perl -pi -e 's/ENCODING/8bit/' *.po &&
perl check_translations.pl *.po
git commit -q -a -m "Update translations from Transifex; changed: $(git status -s | grep -E '^ M' | sed -e 's/ M //' -e 's/.po/ /' | tr -d '\n')" &&
git push -q github translations
