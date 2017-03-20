class ZeroMusic extends ZeroFrame
  selectUser: ->
    @cmd "certSelect", {accepted_domains: ["zeroid.bit"]}
    false

  onOpenWebsocket: ->
    @player = document.getElementById "player"
    @songList = document.getElementById "song_list"
    @cmd "optionalFileList", undefined, (res) =>
      @addSong file.inner_path for file in res

  onRequest: (cmd, message) ->
    if cmd == "setSiteInfo"
      if message.params.cert_user_id
        document.getElementById("select_user").innerHTML = message.params.cert_user_id
      else
        document.getElementById("select_user").innerHTML = "Select user"
      this.site_info = message.params

  playSong: (file) ->
    @player.innerHTML = '<source src="' + file + '" />'
    @player.load();
    @player.play();

  addSong: (file) =>
    @songList.innerHTML += '<li onclick="page.playSong(\'' + file + '\')">' + file + '</li>'

  uploadSong: (e) =>
    filename = "data/songs/" + e.files[0].name.replace /[\s\'\"]/g, ''
    reader = new FileReader()
    reader.onload = (e) =>
      @cmd "fileWrite", [filename, btoa reader.result], (res) =>
        if res == "ok"
          @addSong filename
          @playSong filename
        else
          console.error res
    reader.readAsBinaryString(e.files[0]);

window.page = new ZeroMusic
