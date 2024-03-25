NAME=circuit-railways
VERSION=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' info.json)
DIR_PATH="${NAME}_${VERSION}"
sudo rm -rf ~/.docker/factorio/mods/circuit-railways*
rm -rf ~/.factorio/mods/circuit-railways*
sudo ln -s "$PWD" "$HOME/.docker/factorio/mods/${DIR_PATH}"
ln -s "$PWD" "$HOME/.factorio/mods/${DIR_PATH}"
sudo docker restart factorio