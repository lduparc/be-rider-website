async   = require('async')
express = require('express')
util    = require('util')

app = express.createServer(
  express.logger()
  express.static(__dirname + '/public')
  express.bodyParser()
  express.cookieParser()
  express.session({ secret: process.env.SESSION_SECRET || 'secret123' })
  require('faceplate').middleware({
    app_id: process.env.FACEBOOK_APP_ID
    secret: process.env.FACEBOOK_SECRET
    scope:  'user_likes,user_photos,user_photo_video_tags'
  })
)

port = process.env.PORT || 3000

app.listen port, () ->
  console.log("Listening on " + port)

app.dynamicHelpers(
  'host': (req, res) ->
    req.headers['host']
  'scheme': (req, res) ->
    req.headers['x-forwarded-proto'] || 'http'
  'url': (req, res) ->
    (path) ->
      app.dynamicViewHelpers.scheme(req, res) + app.dynamicViewHelpers.url_no_scheme(path)
  'url_no_scheme': (req, res) ->
    (path) ->
      '://' + app.dynamicViewHelpers.host(req, res) + path
)

render_page = (req, res) ->
  req.facebook.app((app) ->
    req.facebook.me((user) ->
      res.render('index.ejs',
        layout:    false
        req:       req
        app:       app
        user:      user
      )
    )
  )

handle_facebook_request = (req, res) ->

  if (req.facebook.token)
    async.parallel([
      (cb) ->
        req.facebook.get('/me/friends', { limit: 4 }, (friends) ->
          req.friends = friends
          cb()
        )
      (cb) ->
        req.facebook.get('/me/photos', { limit: 16 }, (photos) ->
          req.photos = photos
          cb()
        )
      (cb) ->
        req.facebook.get('/me/likes', { limit: 4 }, (likes) ->
          req.likes = likes
          cb()
        )
      (cb) ->
        req.facebook.fql('SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1', (result) ->
          req.friends_using_app = result
          cb()
        )
    ], () ->
      render_page(req, res)
    )

  else
    render_page(req, res)

app.get('/', handle_facebook_request)
app.post('/', handle_facebook_request)
