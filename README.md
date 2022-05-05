# anonymous-chat
anonymous-chat is a Telegram bot which users can chat with random people without knowing each other. If you buy the VIP, then you can see the username of user that you're chatting with.

This project is using [GroupButler](https://github.com/group-butler/GroupButler) for base codes.

The bot was made for [Tehronia](https://t.me/tehronia) Telegram channel in 2017-2018. The codes are **not well-optimized** and some of the APIs may have been deprecated.

# Installation
```
# Tested on Ubuntu 14.04, 15.04 and 16.04, Debian 7, Linux Mint 17.2

$ sudo apt-get update
$ sudo apt-get upgrade
$ sudo apt-get install libreadline-dev libssl-dev lua5.2 liblua5.2-dev git make unzip redis-server curl libcurl4-gnutls-dev

# We are going now to install LuaRocks and the required Lua modules

$ wget http://luarocks.org/releases/luarocks-2.2.2.tar.gz
$ tar zxpf luarocks-2.2.2.tar.gz
$ cd luarocks-2.2.2
$ ./configure; sudo make bootstrap
$ sudo luarocks install luasec
$ sudo luarocks install luasocket
$ sudo luarocks install redis-lua
$ sudo luarocks install lua-term
$ sudo luarocks install serpent
$ sudo luarocks install dkjson
$ sudo luarocks install lua-cjson
$ sudo luarocks install Lua-cURL
$ cd ..

$ git clone https://github.com/itispey/anonymous-chat.git
$ cd anonymous-chat
$ sudo chmod +x launch.sh
$ sudo chmod +x polling.lua
```
Then, open `polling.lua` and change the package.path to your project path:
```lua
package.path=package.path .. ';/home/user1/anonymous-chat/?.lua'
```
After that, create an `.env` file and place your ID and TOKEN there
```env
TG_TOKEN=123456789:ABCDefGhw3gUmZOq36-D_46_AMwGBsfefbcQ
SUPERADMINS=[12345678]
LOG_CHAT=12345678
LOG_ADMIN=12345678
```
Last but not the least, don't forget to start the `redis-server` ;)
```
$ sudo service redis-server start
```