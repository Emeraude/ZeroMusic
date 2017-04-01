class ZeroMusic extends ZeroFrame
  selectUser: =>
    @cmd "certSelect", {accepted_domains: ["zeroid.bit"]}
    false

  onOpenWebsocket: =>
    @player = document.getElementById "player"
    @artistsList = [];
    @songsList = [];
    @currentFilter = null;
    @cmd "site_info", {}, (site_info) =>
      @siteInfo = site_info
      if @siteInfo.cert_user_id
        document.getElementById("select_user").innerText = @siteInfo.cert_user_id
    @cmd "dbQuery", ["SELECT * FROM songs ORDER BY artist COLLATE NOCASE ASC, title COLLATE NOCASE ASC"], (res) =>
      @addSong file for file in res
      @updateLists()

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
      else
        document.getElementById("select_user").innerHTML = "Select user"

  removeSong: (file) =>
    @cmd "optionalFileDelete", file

  playSong: (file) =>
    @player.innerHTML = '<source src="' + file + '" />'
    @player.load();
    @player.play();

  addSong: (song) =>
    if (@artistsList.findIndex (e) =>
      e == song.artist
    ) == -1
      @artistsList.push song.artist
    @songsList.push song

  updateArtistsList: =>
    @artistsList = @artistsList.sort (a, b) =>
      a.toLowerCase() > b.toLowerCase()
    lis = ''
    for artist in @artistsList
      lis += '<li><span onclick="page.updateSongsList(\'' + artist.replace(/\'/g, "\\'\\'") + '\')">' + artist + '</span></li>'
    document.querySelector('div#artists > ul').innerHTML = lis

  updateSongsList: (filterArtist) =>
    if filterArtist
      @currentFilter = filterArtist
    @songsList = @songsList.sort (a, b) =>
      a.artist.toLowerCase() > b.artist.toLowerCase() and a.title.toLowerCase() > b.title.toLowerCase()
    lis = ''
    @cmd "optionalFileList", [undefined, 'time_downloaded DESC', 999999999], (res) =>
      metadata = {}
      for file in res
        metadata[file.inner_path] = file
      for song in @songsList
        if @currentFilter and song.artist != @currentFilter
          continue
        lis += '<li'
        if not metadata[song.path] or metadata[song.path].is_downloaded != 1
          lis += ' class="remote"'
        lis += '><span class="songButtons"><svg class="removeButton" width="15" height="15" onclick="page.removeSong(\'' + song.path + '\')" xmlns="http://www.w3.org/2000/svg"><path d="M1 15L15 1M1 1l14 14" stroke="#fff" stroke-width="4"/></svg> '
        lis += '<svg class="playButton" width="15" height="15" onclick="page.playSong(\'' + song.path + '\')" xmlns="http://www.w3.org/2000/svg"><path d="M0 0l12 8-12 8z"/></svg></span><strong>' + song.artist + '</strong> - ' + song.title + '</li>'
      document.querySelector('div#songs > ul').innerHTML = lis

  resetFilter: =>
    @currentFilter = null
    @updateSongsList()

  updateLists: =>
    @updateArtistsList()
    @updateSongsList()

  resetSongList: =>
    document.querySelector('div#songs > ul').innerHTML = ''

  updateMetadata: (files) =>
    filename = files.files[0].name.replace(/(_|\.mp3$)/g, ' ').trim()
    if filename.match /^\d+/
      track = parseInt filename
      filename = filename.split(/^\d+\s*([-.]\s*)?/)[2]
    else
      track = "unknown"
    if filename.match /-/
      artist = filename.split('-')[0].trim()
      title = filename.split('-').slice(1).join('-').trim()
    else
      artist = "unknown"
      title = filename.trim()
    document.getElementById('artist').value = artist
    document.getElementById('title').value = title


  getMetadata: (filename) =>
    metadata = {}
    metadata.artist = document.getElementById('artist').value
    metadata.title = document.getElementById('title').value
    return metadata

  uploadSong: (e) =>
    if not @siteInfo.cert_user_id
      return @selectUser()

    name = e.files[0].name
    if !name.match /\.mp3$/
      return @cmd "wrapperNotification", ["error", "Only mp3 files are allowed for now.", 5000]
    @cmd "dbQuery", ["SELECT MAX(id) + 1 as next_id FROM songs"], (res) =>
      id = if res[0] && id != null then res[0].next_id else 1
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
                  @addSong metadata
                  @updateLists()
                  @playSong path
          else
            console.error res
      reader.readAsBinaryString(e.files[0]);

window.page = new ZeroMusic
