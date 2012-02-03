$(document).ready ->
   
    server_url = 'http://127.0.0.1:8080'
    
    $.getScript "#{ server_url }/socket.io/socket.io.js", ->

        main_win = $('#cw-main')
        nick = null

        socket = io.connect server_url
        socket.on 'disconnect_duplicate', ->
            $($('#err-connected-tpl').jqote(null)).dialog {title: 'Error', draggable: false, resizable: false, width: 400}
        socket.on 'reconnect_failed', ->
            $($('#err-disconnected-tpl').jqote(null)).dialog {
                title: 'Error',
                draggable: false,
                resizable: false,
                width: 400, 
                buttons: {Reconnect: -> window.location.reload()}
            }
        
        socket.on 'disconnect', ->
            main_win.append $('#sysmsg-p-tpl').jqote {color: 'red', message: 'Connection failed, attempting to reconnect...'}

        socket.on 'reconnecting', (delay, attempts) ->
            main_win.append $('#sysmsg-p-tpl').jqote {color: 'red', message: "Reconnection attempt #{ attempts }"}

        socket.on 'reconnect', ->
            socket.emit 'auth', nick
            main_win.append $('#sysmsg-p-tpl').jqote {color: 'green', message: 'Reconnected'}
            
        socket.once 'connect_success', ->
            active_win = main_win
        
            getTabButton = (n) -> return $('#chat-tabs li[data-nick="' + n + '"]')
            
            getChatWindow = (n) -> return $('#chat-window div[data-nick="' + n + '"]')
        
            getUserLi = (n) -> return $('#chat-user-ul li[data-nick="' + n + '"]')

            scrollToBottom = ->
                $('#chat-window').animate {scrollTop: $('#chat-window').prop("scrollHeight") - $('#chat-window').height + 999}, 'fast'
        
            newTab = (n) ->
                $('#chat-tabs').append $('#tab-li-tpl').jqote {nick: n}
                $('#chat-window').append $('#cw-div-tpl').jqote {nick: n}

            switchTab = (n) ->
                if active_win.attr('data-nick') == n
                    return
                $('#chat-tabs').children().removeClass 'selected'
                $('#chat-window').children().hide();
                if arguments.length == 0
                    main_win.show()
                    active_win = main_win
                    $('#ct-main').addClass 'selected'
                else
                    sel = getChatWindow n
                    sel.show()
                    active_win = sel
                    getTabButton(n).addClass 'selected'
                scrollToBottom()
                msgFocus()

            createAndSwitchTab = (n, force_switch) ->
                sel = getChatWindow n
                if not sel.length
                    newTab n
                    switchTab n
                else if force_switch
                    switchTab n
                return getChatWindow n

            blockUserToggle = (n) ->
                u = getUserLi n
                if u.attr 'data-blocked'
                    u.removeAttr 'data-blocked'
                    u.removeClass 'blocked'
                else
                    u.attr 'data-blocked', true
                    u.addClass 'blocked'

            isUserBlocked = (n) ->
                return getUserLi(n).attr 'data-blocked'

            sanitize = (t) -> return autolink htmlentities t, "ENT_NOQUOTES"

            msgFocus = -> $('#msg').focus()

            $('#chat-tabs').delegate 'li', 'click', ->
                $('#chat-tabs li.selected').removeClass 'newmsg'
                nick = $(this).attr 'data-nick'
                if nick
                    switchTab nick
                    #getTabButton(nick).removeClass 'newmsg'
                else
                    switchTab()
            
            $('#chat-tabs').delegate 'img.close', 'click', (e) ->
                e.stopPropagation()
                nick = $(this).parent().attr 'data-nick'
                $(this).parent().remove()
                if nick == active_win.attr('data-nick')
                    switchTab()

            socket.on 'user_update', (data) ->
                if data.status == 'connect'
                    $('#chat-user-ul').append $('#nick-li-tpl').jqote data
                    w = getChatWindow data.nick
                    if w.length
                        w.removeAttr 'data-disconnected'
                        w.append $('#sysmsg-p-tpl').jqote {color: 'green', message: 'The remote user has reconnected.'}
                    main_win.append $('#sysmsg-p-tpl').jqote {color: 'green', message: data.nick + ' joined'}
                else
                    getUserLi(data.nick).remove()
                    w = getChatWindow data.nick
                    if w.length
                        w.attr 'data-disconnected', true
                        w.append $('#sysmsg-p-tpl').jqote {color: 'red', message: 'The remote user has disconnected.'}
                    main_win.append $('#sysmsg-p-tpl').jqote {color: 'red', message: data.nick + ' left'}

            socket.on 'chat', (data) ->
                if not isUserBlocked data.nick
                    main_win.append $('#msg-p-tpl').jqote {nick: data.nick, message: data.message}
                if active_win.attr('id') != main_win.attr('id')
                    $('#ct-main').addClass 'newmsg'
                    $('#ct-main').effect 'pulsate', {times: 4}, 1000
                else
                    scrollToBottom()

            socket.on 'pm', (data) ->
                if isUserBlocked data.nick
                    return
                addNew = false
                if active_win.attr('data-nick') != data.nick
                    addNew = true
                t = createAndSwitchTab data.nick, false
                t.append $('#msg-p-tpl').jqote {nick: data.nick, message: data.message}
                if not addNew
                    scrollToBottom()
                tab = getTabButton data.nick
                tab.addClass 'newmsg'
                tab.effect 'pulsate', {times: 4}, 1000

            socket.on 'populate_users', (data) ->
                for d in data
                    $('#chat-user-ul').append $('#nick-li-tpl').jqote {nick: d}

            $('#chat-user-ul').delegate 'li', 'click', ->
                nick = $(this).attr 'data-nick'
                blocktxt = "Block user"
                if $(this).attr 'data-blocked'
                    blocktxt = "Unblock user"

                $($('#user-dlg-tpl').jqote()).dialog {
                    title: 'User Info',
                    buttons: [
                        {
                            text: "Send private message",
                            click: ->
                                createAndSwitchTab nick, true
                                $(this).dialog 'close'
                        }
                        {
                            text: blocktxt, 
                            click: -> 
                                blockUserToggle nick 
                                $(this).dialog 'close'
                        }
                        {
                            text: "Close", 
                            click: -> $(this).dialog 'close'
                        }
                    ],
                    close: -> msgFocus(),
                    modal: true,
                    resizable: false,
                    draggable: false,
                    width: 450
                }

            $('#chat-window').delegate 'a[@href^=http]', 'click', ->
                window.open $(this).attr 'href'
                return false

            $('#sender').submit ->
                m = $('#msg').val()
                if m and m.replace /\s/g, '' != ''
                    if active_win.attr('id') == main_win.attr('id')
                        socket.emit 'chat', m
                    else
                        if isUserBlocked active_win.attr 'data-nick'
                            active_win.append $('#sysmsg-p-tpl').jqote {color: 'red', message: 'You have blocked this user. To send a message, unblock him/her first.'}
                        else if not active_win.attr 'data-disconnected'
                            socket.emit 'pm', {recipient: active_win.attr('data-nick'), message: m}
                        else
                            active_win.append $('#sysmsg-p-tpl').jqote {color: 'red', message: 'The remote user has disconnected.'}
                    active_win.append $('#msg-p-tpl').jqote {nick: nick, message: sanitize m}
                    scrollToBottom()
                    $('#msg').val ''

                return false

            main_win.append $('#sysmsg-p-tpl').jqote {color: 'green', message: 'Welcome to chat!'}
            $('#msg').attr 'disabled', false

        $($('#login-tpl').jqote()).dialog {
            title: "Choose nickname",
            modal: true,
            draggable: false,
            resizable: false,
            buttons: [
                {
                    text: "OK",
                    click: ->
                        n = $('#nick-input').val()
                        if n and n.replace /\s/g, '' != ''
                            nick = n
                            socket.emit('auth', n)
                            $(this).dialog 'close'
                }
            ]
        }

