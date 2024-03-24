NAME=circuit-railways
VERSION=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' info.json)
DIR_PATH="${NAME}_${VERSION}"
ARCHIVE_PATH="${DIR_PATH}.zip"
rm -rf $ARCHIVE_PATH
mkdir $DIR_PATH
cd $DIR_PATH
cp -r ../locale .
cp ../*.{txt,lua,json} .
cp ../thumbnail.png .
rm utils.dev.lua
mv utils.prod.lua utils.lua
cd ../
zip -r $ARCHIVE_PATH $DIR_PATH
rm -rf $DIR_PATH
ls
sudo rm -rf ~/.docker/factorio/mods/circuit-railways*
sudo cp $ARCHIVE_PATH ~/.docker/factorio/mods/
rm -rf ~/.factorio/mods/circuit-railways*
sudo cp $ARCHIVE_PATH ~/.factorio/mods
sudo docker restart factorio