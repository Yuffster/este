suite 'este.App', ->

  App = este.App

  view1 = null
  view2 = null
  view3 = null
  layout = null
  router = null
  app = null

  setup ->
    view1 = createMockView true
    view2 = createMockView()
    view3 = createMockView()
    layout =
      show: ->
      dispose: ->
    router =
      start: ->
        app.load view1
      add: ->
      pathNavigate: ->
      dispose: ->
    arrangeAppWithViews()
    app.start()

  arrangeAppWithViews = ->
    views = [
      view1
      view2
      view3
    ]
    app = new App views, layout, router

  createMockView = (noAsync) ->
    view = new goog.events.EventTarget
    view.load = (result, json) ->
      if noAsync
        result.setValue json
        return
      setTimeout ->
        result.setValue json
      , 4
    view.onLoad = ->
    view.dispose = ->
    view.url = ''
    view

  suite 'constructor', ->
    test 'should work', ->
      assert.instanceOf app, App

  suite 'dispose', ->
    test 'should not leak', ->
      count1 = goog.events.getTotalListenerCount()
      arrangeAppWithViews()
      app.start()
      app.dispose()
      assert.equal count1, goog.events.getTotalListenerCount()

  suite 'start', ->
    test 'should call view1 load then onLoad method', (done) ->
      arrangeAppWithViews()
      loadCalled = false
      view1.load = (result) ->
        loadCalled = true
        result.setValue foo: 'foo'
      view1.onLoad = (json) ->
        assert.isTrue loadCalled
        assert.deepEqual json, foo: 'foo', 'should pass json'
        done()
      app.start()

  suite 'router', ->
    test 'should be prepared in app.start', (done) ->
      arrangeAppWithViews()
      routes = []
      router.add = (url, callback) ->
        routes.push url: url, callback: callback
      router.start = ->
        assert.isTrue router.silentTapHandler
        assert.lengthOf routes, 3
        assert.equal routes[0].url, ''
        assert.isFunction routes[0].callback
        assert.equal routes[1].url, ''
        assert.isFunction routes[1].callback
        assert.equal routes[2].url, ''
        assert.isFunction routes[2].callback
        done()
      app.start()

    test 'should call load on route 0 callback', (done) ->
      arrangeAppWithViews()
      routes = []
      router.add = (url, callback) ->
        routes.push url: url, callback: callback
      app.start()
      app.load = (view, params, isNavigation) ->
        assert.equal view, view1
        assert.deepEqual params, id: 1
        assert.isTrue isNavigation
        done()
      routes[0].callback (id: 1), true

    test 'should call load on route 1 callback', (done) ->
      arrangeAppWithViews()
      routes = []
      router.add = (url, callback) ->
        routes.push url: url, callback: callback
      app.start()
      app.load = (view, params, isNavigation) ->
        assert.equal view, view2
        assert.deepEqual params, id: 2
        assert.isFalse isNavigation
        done()
      routes[1].callback (id: 2), false

  suite 'load', ->
    suite 'view2', ->
      test 'should call view2.onLoad', (done) ->
        view2.onLoad = ->
          done()
        app.load view2

      test 'should call layout.show with view and params', (done) ->
        layout.show = (view, params) ->
          assert.equal view, view2
          assert.deepEqual params, id: 1
          done()
        app.load view2, id: 1

      test 'should dispatch beforeload event', (done) ->
        goog.events.listenOnce app, 'beforeload', (e) ->
          assert.deepEqual e.request,
            view: view2
            params: id: 1
            silent: false
          done()
        app.load view2, id: 1

      test 'should dispatch beforeshow event', (done) ->
        goog.events.listenOnce app, 'beforeshow', (e) ->
          assert.deepEqual e.request,
            view: view2
            params: id: 1
            silent: false
          done()
        app.load view2, id: 1

      test 'should call router.pathNavigate if urlEnabled', (done) ->
        router.pathNavigate = (url, params, silent) ->
          assert.equal url, ''
          assert.deepEqual params, id: 1
          assert.isTrue silent
          done()
        app.urlEnabled = true
        app.load view2, id: 1, false

      test 'should not call router.pathNavigate if urlEnabled but view has null url', ->
        called = false
        router.pathNavigate = (url, params, silent) ->
          called = true
        app.urlEnabled = true
        view1.url = null
        app.load view1, id: 1, false
        assert.isFalse called

      test 'should not call router.pathNavigate if urlEnabled == false', ->
        called = false
        router.pathNavigate = (url, params, silent) ->
          called = true
        app.urlEnabled = false
        app.load view1, id: 1, false
        assert.isFalse called

    suite 'view2 twice async', ->
      test 'should call view2.onLoad once', (done) ->
        view2.onLoad = ->
          done()
        app.load view2
        setTimeout ->
          app.load view2
        , 2

    suite 'view 2, view 3 async', ->
      test 'should call view3.onLoad', (done) ->
        view3.onLoad = ->
          done()
        app.load view2
        setTimeout ->
          app.load view3
        , 2

    suite 'view 2, view 3, view2 async', ->
      test 'should call view2.onLoad', (done) ->
        view2.onLoad = ->
          done()
        app.load view2
        setTimeout ->
          app.load view3
        , 2
        setTimeout ->
          app.load view2
        , 4

  suite 'dispose', ->
    test 'should dispose pendingRequests, views and layout', ->
      calls = ''
      view1.dispose = -> calls += '0'
      view2.dispose = -> calls += '1'
      view3.dispose = -> calls += '2'
      layout.dispose = -> calls += '3'
      router.dispose = -> calls += '4'
      app.dispose()
      assert.equal app.pendingRequests.length, 0
      assert.equal calls, '01234'

  # suite 'load', ->
  #   test 'should be called on view redirect event', (done) ->
  #     app.load = (view, params) ->
  #       assert.instanceOf view, goog.events.EventTarget
  #       assert.deepEqual params, 1: 'foo'
  #       done()
  #     goog.events.fireListeners view1, 'redirect', false,
  #       type: 'redirect'
  #       target: view1
  #       viewClass: goog.events.EventTarget
  #       params: 1: 'foo'