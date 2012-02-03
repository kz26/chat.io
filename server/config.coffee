port = 8080;
hostname = '0.0.0.0'
log_chat = true
log_pm = true # slightly unethical

auth = (nick, cb) ->
    cb {nick: nick, room: 'main'}

exports.port = port
exports.hostname = hostname
exports.auth = auth
exports.log_chat = true
exports.log_pm = true
