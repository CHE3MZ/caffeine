cd scripts
sh build-app.sh
cd ..
cd build
create-dmg --overwrite --no-version-in-filename Caffeine.app
exit