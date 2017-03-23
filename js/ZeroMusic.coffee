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
    @cmd "optionalFileList", undefined, (res) =>
      @addSong file.inner_path for file in res

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

  addSong: (file) =>
    @songList.innerHTML += '<li onclick="page.playSong(\'' + file + '\')">' + file + '</li>'

  uploadSong: (e) =>
    if not @siteInfo.cert_user_id
      return @selectUser()
    name = "data/users/" + @siteInfo.auth_address + '/' + e.files[0].name.replace /[\s\'\"\(\)]/g, ''
    reader = new FileReader()
    reader.onload = (e) =>
      @cmd "fileWrite", [name, btoa reader.result], (res) =>
        if res == "ok"
          @cmd "sitePublish", {inner_path: "data/users/" + @siteInfo.auth_address + "/content.json", sign: true}, (res) =>
            console.log res
          @addSong name
          @playSong name
        else
          console.error res
    reader.readAsBinaryString(e.files[0]);

window.page = new ZeroMusic
