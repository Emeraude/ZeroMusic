class ZeroMusic extends ZeroFrame
  selectUser: =>
    @cmd "certSelect", {accepted_domains: ["zeroid.bit"]}
    false

  onOpenWebsocket: =>
    @player = document.getElementById "player"
    @cmd "site_info", {}, (site_info) =>
      @siteInfo = site_info
      if @siteInfo.cert_user_id
        document.getElementById("select_user").innerText = @siteInfo.cert_user_id
    @cmd "dbQuery", ["SELECT * FROM songs ORDER BY artist COLLATE NOCASE ASC, title COLLATE NOCASE ASC"], (res) =>
      @addSong file for file in res

  onRequest: (cmd, message) =>
    if cmd == "setSiteInfo"
      @siteInfo = message.params
      if message.params.cert_user_id
        document.getElementById("select_user").innerHTML = @siteInfo.cert_user_id
        @cmd "fileGet", ["data/users/" + @siteInfo.auth_address + "/content.json", false], (data) =>
          data = if data then JSON.parse(data) else {}
          data.optional = ".+mp3"
          data.modified = Date.now() / 1000;
          jsonRaw = unescape(encodeURIComponent(JSON.stringify(data, undefined, 1)));
          @cmd "fileWrite", ["data/users/" + @siteInfo.auth_address + "/content.json", btoa(jsonRaw)], (res) =>
            console.log(res)
      else
        document.getElementById("select_user").innerHTML = "Select user"

  removeSong: (file) =>
    @cmd "optionalFileDelete", file

  playSong: (file) =>
    @player.innerHTML = '<source src="' + file + '" />'
    @player.load();
    @player.play();

  addSong: (song) =>
    @cmd "optionalFileInfo", song.path, (res) =>
      if not document.querySelector('div#artists > ul > li[data-content="' + song.artist + '" i]')
        document.querySelector('div#artists > ul').innerHTML += '<li data-content="' + song.artist + '"><span onclick="page.filterByArtist(\'' + song.artist.replace(/\'/g, "\\'\\'") + '\')">' + song.artist + '</span></li>'
      li = '<li'
      if res.is_downloaded != 1
        li += ' class="remote"'
      li += '><span class="songButtons"><svg class="removeButton" width="15" height="15" onclick="page.removeSong(\'' + song.path + '\')" xmlns="http://www.w3.org/2000/svg"><path d="M1 15L15 1M1 1l14 14" stroke="#fff" stroke-width="4"/></svg> '
      li += '<svg class="playButton" width="15" height="15" onclick="page.playSong(\'' + song.path + '\')" xmlns="http://www.w3.org/2000/svg"><path d="M0 0l12 8-12 8z"/></svg></span><strong>' + song.artist + '</strong> - ' + song.title + '</li>'
      document.querySelector('div#songs > ul').innerHTML += li

  resetSongList: =>
    document.querySelector('div#songs > ul').innerHTML = ''

  filterByArtist: (artist) =>
    @cmd "dbQuery", ["SELECT * FROM songs WHERE artist = '#{artist}' ORDER BY title COLLATE NOCASE ASC"], (res) =>
      if not res.error
        @resetSongList()
        @addSong file for file in res

  getMetadata: (filename) =>
    filename = filename.replace(/(_|\.mp3$)/g, ' ').trim()
    metadata = {}
    if filename.match /^\d+/
      metadata.track = parseInt filename
      filename = filename.split(/^\d+\s*([-.]\s*)?/)[2]
    else
      metadata.track = "unknown"
    if filename.match /-/
      metadata.artist = filename.split('-')[0].trim()
      metadata.title = filename.split('-').slice(1).join('-').trim()
    else
      metadata.artist = "unknown"
      metadata.title = filename.trim()
    return metadata

  uploadSong: (e) =>
    if not @siteInfo.cert_user_id
      return @selectUser()

    name = e.files[0].name
    if !name.match /\.mp3$/
      return @cmd "wrapperNotification", ["error", "Only mp3 files are allowed for now.", 5000]
    @cmd "dbQuery", ["SELECT MAX(id) + 1 as next_id FROM songs"], (res) =>
      id = if res[0] then res[0].next_id else 1
      path = "data/users/" + @siteInfo.auth_address + '/' + id + '.mp3'
      metadata = @getMetadata name
      metadata.path = path
      metadata.id = id
      reader = new FileReader()
      reader.onload = (e) =>
        @cmd "fileWrite", [path, btoa reader.result], (res) =>
          if res == "ok"
            @cmd "fileGet", ["data/users/" + @siteInfo.auth_address + "/data.json", false], (data) =>
              data = if data then JSON.parse(data) else {songs:[]}
              data.songs.push metadata
              json_raw = unescape encodeURIComponent JSON.stringify data, undefined, 1
              @cmd "fileWrite", ["data/users/" + @siteInfo.auth_address + "/data.json", btoa(json_raw)], (res) =>
                @cmd "sitePublish", {inner_path: "data/users/" + @siteInfo.auth_address + "/content.json", sign: true}, (res) =>
                  console.log res
                  @addSong metadata
                  @playSong path
          else
            console.error res
      reader.readAsBinaryString(e.files[0]);

window.page = new ZeroMusic
