local count = ya.sync(function() return #cx.tabs end)

return {
  entry = function (_, job)
    local quitargs = job.args[1] == 'no-cwd-file' and { ["no-cwd-file"] = true } or {}

    if count() < 2 then
      return ya.emit("quit", quitargs)
    end

    local yes = ya.confirm {
      pos = { "center", w = 62, h = 10 },
      title = "Quit?",
      body = ui.Text("There are multiple tabs open. Are you sure you want to quit?"):wrap(ui.Wrap.YES),
    }
    if yes then
      ya.emit("quit", quitargs)
    end
  end
}
