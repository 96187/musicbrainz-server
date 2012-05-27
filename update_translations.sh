cd /home/i18n/musicbrainz-server &&
git pull -q nikki translations &&
cd po &&
touch mb_server.pot &&
make install
