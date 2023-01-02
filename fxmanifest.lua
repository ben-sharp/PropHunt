fx_version 'cerulean'
game 'gta5'

author 'mOsh'
description 'Prop Hunt aka Hide n Seek'
version '1.0.0'

resource_type 'gametype' { name = 'Prop Hunt' }

client_scripts {
    '@PolyZone/client.lua',
    'prophunt_client.lua'
}
server_script 'prophunt_server.lua'