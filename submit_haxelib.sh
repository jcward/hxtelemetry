echo "Be sure to check version number in haxelib.json:"
cat haxelib.json | grep -i version
echo "lib.haxe.org currently has:"
curl -s https://lib.haxe.org/p/hxtelemetry | grep '<title'
sleep 1
read -r -p "Are you sure? [y/N] " response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
then
  rm -f hxtelemetry.zip
  zip -r hxtelemetry.zip amf hxtelemetry haxelib.json include.xml README.md LICENSE
  haxelib submit hxtelemetry.zip
else
  echo "Cancelled"
fi
