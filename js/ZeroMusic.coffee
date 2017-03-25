class ZeroMusic extends ZeroFrame
  selectUser: =>
    @cmd "certSelect", {accepted_domains: ["zeroid.bit"]}
    false

  onOpenWebsocket: =>
    @player = document.getElementById "player"
    @songList = document.getElementById "song_list"
    @cmd "site_info", {}, (site_info) =>
      @siteInfo = site_info
      if @siteInfo.cert_user_id
        document.getElementById("select_user").innerText = @siteInfo.cert_user_id
    @cmd "dbQuery", ["SELECT * FROM songs"], (res) =>
      @addSong file for file in res

  onRequest: (cmd, message) =>
    if cmd == "setSiteInfo"
      @siteInfo = message.params
      if message.params.cert_user_id
        document.getElementById("select_user").innerHTML = @siteInfo.cert_user_id
        @cmd "fileGet", ["data/users/" + @siteInfo.auth_address + "/content.json", false], (data) =>
          data = if data then JSON.parse(data) else {}
          data.optional = ".+mp3"
          data.modified = Date.now();
          jsonRaw = unescape(encodeURIComponent(JSON.stringify(data, undefined, 1)));
          @cmd "fileWrite", ["data/users/" + @siteInfo.auth_address + "/content.json", btoa(jsonRaw)], (res) =>
            console.log(res)
      else
        document.getElementById("select_user").innerHTML = "Select user"

  playSong: (file) =>
    @player.innerHTML = '<source src="' + file + '" />'
    @player.load();
    @player.play();

  addSong: (song) =>
    @songList.innerHTML += '<li onclick="page.playSong(\'' + song.path + '\')"><strong>' + song.artist + '</strong> - ' + song.title + '</li>'

  updateDataFile: (name, path, cb) =>
    @cmd "fileGet", ["data/users/" + @siteInfo.auth_address + "/data.json", false], (data) =>
      data = if data then JSON.parse(data) else {songs:[]}
      data.songs.push {id: 12, title: name, artist: name, track: 1, path: path}
      json_raw = unescape encodeURIComponent JSON.stringify data, undefined, 1
      @cmd "fileWrite", ["data/users/" + @siteInfo.auth_address + "/data.json", btoa(json_raw)], (res) =>
        cb res

  uploadSong: (e) =>
    if not @siteInfo.cert_user_id
      return @selectUser()

    name = e.files[0].name.replace /\W/g, ''
    path = "data/users/" + @siteInfo.auth_address + '/' + name
    reader = new FileReader()
    reader.onload = (e) =>
      @cmd "fileWrite", [path, btoa reader.result], (res) =>
        if res == "ok"
          @updateDataFile name, path, (res) =>
            @cmd "sitePublish", {inner_path: "data/users/" + @siteInfo.auth_address + "/content.json", sign: true}, (res) =>
              console.log res
          @addSong path
          @playSong path
        else
          console.error res
    reader.readAsBinaryString(e.files[0]);

window.page = new ZeroMusic
