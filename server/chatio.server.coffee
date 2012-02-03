http = require('http')
sio = require('socket.io')
moment = require('moment')
strip = require('./strip.min.js')
autolink = require('./autolink.js')
config = require('./config.js')

alphaSort = (A, B) ->
    a = A.toLowerCase()
    b = B.toLowerCase()
    if a < b
        return -1
    if a > b
        return 1
    return 0

sanitize = (t) ->
    return autolink.autolink strip.htmlentities t, "ENT_NOQUOTES"

dtNow = -> return "[#{ moment().format('MM/DD/YYYY hh:mm:ss A') }]"

bindChat = (a) ->
    io = sio.listen(a)
    io.enable('browser client minification')
    io.enable('browser client etag')
    io.enable('browser client gzip')
    io.set('log level', 1)


    online = {}

    io.sockets.on 'connection', (client) ->
        client.on 'auth', (data) ->
            config.auth data, (credentials) ->
                console.log("#{ dtNow() } #{ client.id } authenticated successfully")
                if online[credentials.nick] != undefined
                    console.log " #{ dtNow() } #{ credentials.nick } already connected - disconnecting old socket"
                    online[credentials.nick].emit('disconnect_duplicate', null)
                    online[credentials.nick].disconnect()
                client.emit 'connect_success', null
                client.nick = credentials.nick
                client.room = credentials.room
                online[client.nick] = client
                console.log "#{ dtNow() } #{ client.id } assigned nickname #{ client.nick }" 
                client.join(client.room)
                console.log "#{ dtNow() } #{ client.nick } assigned to room #{ client.room }"
                
                members = []
                for k,v of io.sockets.clients(client.room)
                    if v.nick != client.nick and !v.disconnected and members.indexOf(v.nick) == -1
                        members.push v.nick
                members.sort(alphaSort)
                client.emit('populate_users', members)
                client.broadcast.to(client.room).emit 'user_update', {'status': 'connect', nick: client.nick}

                client.on 'chat', (msg) ->
                    if config.log_chat
                        console.log "#{ dtNow() } #{ client.nick }: #{ sanitize(msg) } "
                    client.broadcast.to(client.room).emit 'chat', {nick: client.nick, message: sanitize(msg)}

                client.on 'pm', (pm) ->
                    if config.log_pm
                        console.log "#{ dtNow() } [PM] #{ client.nick } to #{ pm.recipient }: #{ pm.message }"
                    online[pm.recipient].emit 'pm', {nick: client.nick, message: sanitize(pm.message)}

                client.on 'disconnect', ->
                    console.log "#{ dtNow() } #{ client.nick } disconnected"
                    delete online[client.nick]
                    client.broadcast.to(client.room).emit 'user_update', {status: 'disconnect', nick: client.nick}

start = ->
    app = http.createServer()
    app.listen(config.port, config.hostname)
    bindChat(app)

start()
